import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/domain/entities/session_end_reason.dart';
import 'package:stridequest/features/runs/data/health_sync_service.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/services/health_sync.dart';
import 'package:stridequest/features/runs/domain/usecases/sync_activity.dart';

import '../../../helpers/auth_fixtures.dart';
import '../../../helpers/health_fixtures.dart';
import '../../../helpers/runs_fixtures.dart';

/// A health repository whose reads wait for the test to release them.
class _GatedHealthRepository extends FakeHealthRepository {
  final gates = <Completer<ActivityReading>>[];
  Object? accessError;

  @override
  Future<ActivityReading> readToday(Set<HealthMetric> allowed) {
    readTodayCalls++;
    final gate = Completer<ActivityReading>();
    gates.add(gate);
    return gate.future;
  }

  @override
  Future<HealthAccess> checkAccess() {
    if (accessError != null) return Future.error(accessError!);
    return super.checkAccess();
  }
}

ActivityReading _at(int steps) =>
    ActivityReading(readAt: DateTime(2026, 10, 19, 10), steps: steps);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHealthRepository health;
  late FakeRunsRepository runs;
  late MockAuthRepository auth;
  late StreamController<AuthUser> sessionStarted;
  late StreamController<SessionEndReason> sessionEnded;
  late StreamController<void> accountDeleted;
  late DateTime now;
  late HealthSyncService service;

  HealthSyncService build(FakeHealthRepository repo) =>
      HealthSyncService.withClock(
        repo,
        auth,
        SyncActivity(repo, runs, FakeSyncStateRepository()),
        () => now,
      );

  setUp(() {
    health = FakeHealthRepository();
    runs = FakeRunsRepository();
    auth = MockAuthRepository();
    sessionStarted = StreamController<AuthUser>.broadcast();
    sessionEnded = StreamController<SessionEndReason>.broadcast();
    accountDeleted = StreamController<void>.broadcast();
    now = DateTime(2026, 10, 19, 10);
    when(auth.restoreSession).thenAnswer((_) async => testUser.toEntity());
    when(() => auth.sessionStarted).thenAnswer((_) => sessionStarted.stream);
    when(() => auth.sessionEnded).thenAnswer((_) => sessionEnded.stream);
    when(() => auth.accountDeleted).thenAnswer((_) => accountDeleted.stream);
    service = build(health);
  });

  tearDown(() async {
    await service.dispose();
    await sessionStarted.close();
    await sessionEnded.close();
    await accountDeleted.close();
  });

  test('cold start runs a sync', () async {
    service.start();
    await service.sync(); // joins the one start began
    expect(health.readTodayCalls, 1);
    expect(service.state.reading, health.reading);
    expect(service.state.syncedAt, health.reading.readAt);
  });

  test('a trigger within 5 minutes of a finished sync does nothing', () async {
    await service.sync();
    now = now.add(const Duration(minutes: 4, seconds: 59));
    await service.sync();
    expect(health.readTodayCalls, 1);
  });

  test('a trigger after 5 minutes runs again', () async {
    await service.sync();
    now = now.add(const Duration(minutes: 5));
    await service.sync();
    expect(health.readTodayCalls, 2);
  });

  test('two triggers at once run one sync', () async {
    await Future.wait([service.sync(), service.sync()]);
    expect(health.readTodayCalls, 1);
  });

  test('signed out does not run', () async {
    when(auth.restoreSession).thenAnswer((_) async => null);
    await service.sync();
    expect(health.readTodayCalls, 0);
    expect(service.state.busy, isFalse);
  });

  test('steps not allowed does not run', () async {
    health.access = const HealthAccess(
      HealthAccessStatus.granted,
      allowed: {HealthMetric.sleep},
    );
    await service.sync();
    expect(health.readTodayCalls, 0);

    health.access = const HealthAccess.denied();
    await service.sync();
    expect(health.readTodayCalls, 0);
  });

  test('a new session runs a sync even inside the throttle', () async {
    await service.sync();
    service.start();
    await service.sync(); // joins the cold start, throttled, nothing to do
    health.readTodayCalls = 0;
    sessionStarted.add(testUser.toEntity());
    await pumpEventQueue();
    expect(health.readTodayCalls, 1);
  });

  test('a health failure is exposed, not thrown, and is retried', () async {
    health.readError = const HealthFailure();
    await service.sync();
    expect(service.state.error, const HealthFailure().message);
    expect(service.state.reading, isNull);
    expect(service.state.busy, isFalse);

    health.readError = null;
    await service.sync(); // the failure did not start the throttle
    expect(service.state.error, isNull);
    expect(service.state.reading, health.reading);
  });

  test('a backend failure does not start the throttle', () async {
    runs.earliest = DateTime.utc(2026, 10, 15);
    runs.error = const RunsFailure(RunsFailureCode.network);
    await service.sync();
    expect(
      service.state.error,
      const RunsFailure(RunsFailureCode.network).message,
    );
    expect(service.state.syncedAt, isNull);
    runs.error = null;
    await service.sync();
    expect(health.readTodayCalls, 2);
    expect(service.state.error, isNull);
  });

  test('a failure after an earlier success reopens the throttle', () async {
    await service.sync();
    now = now.add(const Duration(minutes: 1));
    runs.earliest = DateTime.utc(2026, 10, 15);
    runs.error = const RunsFailure(RunsFailureCode.network);
    await service.sync(force: true);
    expect(service.state.error, isNotNull);

    runs.error = null;
    now = now.add(const Duration(minutes: 1));
    await service.sync();
    expect(health.readTodayCalls, 3);
    expect(service.state.error, isNull);
  });

  test('force skips the throttle', () async {
    await service.sync();
    await service.sync(force: true);
    expect(health.readTodayCalls, 2);
  });

  test('syncNow skips the throttle', () async {
    await service.sync();
    await service.syncNow();
    expect(health.readTodayCalls, 2);
  });

  test('syncNow does not run when steps are not allowed', () async {
    health.access = const HealthAccess.denied();
    await service.syncNow();
    expect(health.readTodayCalls, 0);
  });

  group('with a read in flight', () {
    late _GatedHealthRepository gated;

    setUp(() {
      gated = _GatedHealthRepository();
      service = build(gated)..start();
    });

    test('a new session drops the old result and runs again', () async {
      await pumpEventQueue();
      expect(gated.gates, hasLength(1));
      expect(service.state.busy, isTrue);

      sessionStarted.add(testUser.toEntity());
      await pumpEventQueue();
      expect(service.state, const HealthSyncState());
      expect(gated.gates, hasLength(1)); // the follow-up waits for the old run

      gated.gates[0].complete(_at(1)); // the previous user's figures
      await pumpEventQueue();
      expect(gated.gates, hasLength(2));
      expect(service.state.reading, isNull);
      expect(service.state.busy, isTrue);

      gated.gates[1].complete(_at(2));
      await pumpEventQueue();
      expect(service.state.reading, _at(2));
      expect(service.state.busy, isFalse);
      expect(gated.readTodayCalls, 2);
    });

    test('the old run does not throttle the new session', () async {
      await pumpEventQueue();
      sessionStarted.add(testUser.toEntity());
      await pumpEventQueue();
      gated.gates[0].complete(_at(1));
      await pumpEventQueue();
      gated.gates[1].complete(_at(2));
      await pumpEventQueue();
      expect(gated.readTodayCalls, 2); // not skipped by the 5-minute throttle
    });

    test('a session end or account deletion drops the result', () async {
      await pumpEventQueue();
      sessionEnded.add(SessionEndReason.expired);
      await pumpEventQueue();
      expect(service.state, const HealthSyncState());
      gated.gates[0].complete(_at(1));
      await pumpEventQueue();
      expect(service.state, const HealthSyncState());

      final next = service.sync();
      await pumpEventQueue();
      accountDeleted.add(null);
      await pumpEventQueue();
      gated.gates[1].complete(_at(2));
      await next;
      expect(service.state, const HealthSyncState());
    });

    test('syncNow queues one follow-up and calls share it', () async {
      await pumpEventQueue();
      final a = service.syncNow();
      final b = service.syncNow();
      expect(gated.gates, hasLength(1));
      gated.gates[0].complete(_at(1));
      await pumpEventQueue();
      expect(gated.gates, hasLength(2));
      gated.gates[1].complete(_at(2));
      await Future.wait([a, b]);
      expect(gated.gates, hasLength(2));
      expect(service.state.reading, _at(2));
    });

    test('force queues exactly one follow-up', () async {
      await pumpEventQueue();
      final a = service.sync(force: true);
      final b = service.sync(force: true);
      final c = service.sync();
      expect(gated.gates, hasLength(1));
      gated.gates[0].complete(_at(1));
      await pumpEventQueue();
      expect(gated.gates, hasLength(2));
      gated.gates[1].complete(_at(2));
      await Future.wait([a, b, c]);
      expect(gated.gates, hasLength(2));
      expect(service.state.reading, _at(2));
    });
  });

  group('state resets', () {
    test('when idle, a session end or account deletion empties it', () async {
      service.start();
      await pumpEventQueue();
      expect(service.state.reading, isNotNull);
      sessionEnded.add(SessionEndReason.expired);
      await pumpEventQueue();
      expect(service.state, const HealthSyncState());

      await service.sync();
      expect(service.state.reading, isNotNull);
      accountDeleted.add(null);
      await pumpEventQueue();
      expect(service.state, const HealthSyncState());
    });
  });

  test('a changed allowed set skips the throttle', () async {
    await service.sync();
    health.access = const HealthAccess(
      HealthAccessStatus.granted,
      allowed: {HealthMetric.steps, HealthMetric.sleep},
    );
    now = now.add(const Duration(minutes: 1));
    await service.sync();
    expect(health.readTodayCalls, 2);
    await service.sync(); // same set again: throttled
    expect(health.readTodayCalls, 2);
  });

  test('an access check that throws is an error, not busy', () async {
    final gated = _GatedHealthRepository()..accessError = StateError('boom');
    service = build(gated);
    final reports = <FlutterErrorDetails>[];
    final onError = FlutterError.onError;
    FlutterError.onError = reports.add;
    addTearDown(() => FlutterError.onError = onError);

    await service.sync();
    expect(reports, hasLength(1));
    expect(service.state.busy, isFalse);
    expect(service.state.error, const HealthFailure().message);
  });
}

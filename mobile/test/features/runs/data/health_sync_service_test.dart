import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/runs/data/health_sync_service.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/usecases/sync_activity.dart';

import '../../../helpers/auth_fixtures.dart';
import '../../../helpers/health_fixtures.dart';
import '../../../helpers/runs_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHealthRepository health;
  late FakeRunsRepository runs;
  late MockAuthRepository auth;
  late StreamController<AuthUser> sessionStarted;
  late DateTime now;
  late HealthSyncService service;

  setUp(() {
    health = FakeHealthRepository();
    runs = FakeRunsRepository();
    auth = MockAuthRepository();
    sessionStarted = StreamController<AuthUser>.broadcast();
    now = DateTime(2026, 10, 19, 10);
    when(auth.restoreSession).thenAnswer((_) async => testUser.toEntity());
    when(() => auth.sessionStarted).thenAnswer((_) => sessionStarted.stream);
    when(() => auth.sessionEnded).thenAnswer((_) => const Stream.empty());
    when(() => auth.accountDeleted).thenAnswer((_) => const Stream.empty());
    service = HealthSyncService.withClock(
      health,
      auth,
      SyncActivity(health, runs, FakeSyncStateRepository()),
      () => now,
    );
  });

  tearDown(() async {
    await service.dispose();
    await sessionStarted.close();
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

  test('force skips the throttle', () async {
    await service.sync();
    await service.sync(force: true);
    expect(health.readTodayCalls, 2);
  });
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/runs/data/health_sync_service.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/services/health_sync.dart';
import 'package:stridequest/features/runs/domain/usecases/sync_activity.dart';
import 'package:stridequest/features/runs/presentation/bloc/activity_bloc.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/health_fixtures.dart';
import '../../../../helpers/runs_fixtures.dart';

const _allowed = {HealthMetric.steps, HealthMetric.sleep};
final _reading = ActivityReading(
  readAt: DateTime(2026, 10, 19, 21, 55),
  steps: 5490,
  sleepMinutes: 390,
);

/// A [HealthSync] a test drives by hand.
class _FakeHealthSync implements HealthSync {
  final _controller = StreamController<HealthSyncState>.broadcast();
  var syncs = 0;
  @override
  HealthSyncState state = const HealthSyncState();

  bool get hasListener => _controller.hasListener;

  void emit(HealthSyncState next) {
    state = next;
    _controller.add(next);
  }

  @override
  Stream<HealthSyncState> get stream => _controller.stream;

  @override
  Future<void> sync({bool force = false}) async => syncs++;

  @override
  Future<void> syncNow() async => syncs++;

  @override
  void start() {}

  @override
  Future<void> dispose() => _controller.close();
}

void main() {
  late FakeHealthRepository health;
  late FakeRunsRepository runs;
  late HealthSyncService service;

  setUp(() {
    health = FakeHealthRepository()..reading = _reading;
    runs = FakeRunsRepository();
    final auth = MockAuthRepository();
    when(auth.restoreSession).thenAnswer((_) async => testUser.toEntity());
    service = HealthSyncService.withClock(
      health,
      auth,
      SyncActivity(health, runs, FakeSyncStateRepository()),
      () => DateTime(2026, 10, 19, 21, 55),
    );
  });

  tearDown(() => service.dispose());

  ActivityBloc bloc() => ActivityBloc(service);

  blocTest<ActivityBloc, ActivityState>(
    'opening with no result yet asks the service to sync and shows it',
    build: bloc,
    act: (bloc) => bloc.add(const ActivityStarted(_allowed)),
    expect: () => [
      const ActivityState(allowed: _allowed),
      const ActivityState(allowed: _allowed, busy: true),
      ActivityState(
        allowed: _allowed,
        reading: _reading,
        syncedAt: _reading.readAt,
      ),
    ],
  );

  blocTest<ActivityBloc, ActivityState>(
    'opening shows the latest result without syncing again',
    build: bloc,
    setUp: () async => service.sync(),
    act: (bloc) => bloc.add(const ActivityStarted(_allowed)),
    expect: () => [
      ActivityState(
        allowed: _allowed,
        reading: _reading,
        syncedAt: _reading.readAt,
      ),
    ],
    verify: (_) => expect(health.readTodayCalls, 1),
  );

  blocTest<ActivityBloc, ActivityState>(
    'refresh forces a sync and shows the new figures',
    build: bloc,
    setUp: () async => service.sync(),
    act: (bloc) async {
      bloc.add(const ActivityStarted(_allowed));
      await Future<void>.delayed(Duration.zero);
      health.reading = ActivityReading(
        readAt: DateTime(2026, 10, 19, 22),
        steps: 6000,
      );
      bloc.add(const ActivityRefreshRequested());
    },
    skip: 1,
    expect: () => [
      ActivityState(
        allowed: _allowed,
        reading: _reading,
        syncedAt: _reading.readAt,
        busy: true,
      ),
      ActivityState(
        allowed: _allowed,
        reading: ActivityReading(
          readAt: DateTime(2026, 10, 19, 22),
          steps: 6000,
        ),
        syncedAt: DateTime(2026, 10, 19, 22),
      ),
    ],
  );

  blocTest<ActivityBloc, ActivityState>(
    'a sync that fails to reach the backend shows the reading and the error',
    build: bloc,
    setUp: () {
      runs.earliest = DateTime.utc(2026, 10, 15);
      runs.error = const RunsFailure(RunsFailureCode.network);
    },
    act: (bloc) => bloc.add(const ActivityStarted(_allowed)),
    skip: 2,
    expect: () => [
      ActivityState(
        allowed: _allowed,
        reading: _reading,
        error: const RunsFailure(RunsFailureCode.network).message,
      ),
    ],
  );

  blocTest<ActivityBloc, ActivityState>(
    'a health read that fails keeps what was on screen',
    build: bloc,
    setUp: () async {
      await service.sync();
      health.readError = const HealthFailure();
    },
    act: (bloc) async {
      bloc.add(const ActivityStarted(_allowed));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ActivityRefreshRequested());
    },
    skip: 2,
    expect: () => [
      ActivityState(
        allowed: _allowed,
        reading: _reading,
        syncedAt: _reading.readAt,
        error: const HealthFailure().message,
      ),
    ],
  );

  blocTest<ActivityBloc, ActivityState>(
    'a refresh while one is running is ignored',
    build: bloc,
    seed: () => const ActivityState(allowed: _allowed, busy: true),
    act: (bloc) => bloc.add(const ActivityRefreshRequested()),
    expect: () => <ActivityState>[],
    verify: (_) => expect(health.readTodayCalls, 0),
  );

  group('with a fake HealthSync', () {
    late _FakeHealthSync fake;

    setUp(() => fake = _FakeHealthSync());
    tearDown(() => fake.dispose());

    blocTest<ActivityBloc, ActivityState>(
      'follows a sync the service starts on its own and a later success '
      'clears an earlier error',
      build: () => ActivityBloc(fake),
      act: (bloc) async {
        bloc.add(const ActivityStarted(_allowed));
        await Future<void>.delayed(Duration.zero);
        fake.emit(HealthSyncState(reading: _reading, error: 'offline'));
        await Future<void>.delayed(Duration.zero);
        fake.emit(
          HealthSyncState(reading: _reading, syncedAt: _reading.readAt),
        );
      },
      skip: 1,
      expect: () => [
        ActivityState(allowed: _allowed, reading: _reading, error: 'offline'),
        ActivityState(
          allowed: _allowed,
          reading: _reading,
          syncedAt: _reading.readAt,
        ),
      ],
      verify: (_) => expect(fake.syncs, 1),
    );

    test('stops listening to the service when closed', () async {
      final bloc = ActivityBloc(fake)..add(const ActivityStarted(_allowed));
      await Future<void>.delayed(Duration.zero);
      expect(fake.hasListener, isTrue);
      await bloc.close();
      expect(fake.hasListener, isFalse);
    });
  });
}

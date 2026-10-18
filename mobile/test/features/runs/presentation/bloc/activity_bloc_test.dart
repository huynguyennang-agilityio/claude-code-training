import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/usecases/sync_activity.dart';
import 'package:stridequest/features/runs/presentation/bloc/activity_bloc.dart';

import '../../../../helpers/health_fixtures.dart';
import '../../../../helpers/runs_fixtures.dart';

const _allowed = {HealthMetric.steps, HealthMetric.sleep};
final _reading = ActivityReading(
  readAt: DateTime(2026, 10, 19, 21, 55),
  steps: 5490,
  sleepMinutes: 390,
);

void main() {
  late FakeHealthRepository health;
  late FakeRunsRepository runs;

  setUp(() {
    health = FakeHealthRepository()..reading = _reading;
    runs = FakeRunsRepository();
  });

  ActivityBloc bloc() => ActivityBloc(SyncActivity(health, runs));

  blocTest<ActivityBloc, ActivityState>(
    'starting reads and syncs, and remembers when it reached StrideQuest',
    build: bloc,
    act: (bloc) => bloc.add(const ActivityStarted(_allowed)),
    expect: () => [
      const ActivityState(allowed: _allowed, busy: true),
      ActivityState(
        allowed: _allowed,
        reading: _reading,
        syncedAt: _reading.readAt,
      ),
    ],
  );

  blocTest<ActivityBloc, ActivityState>(
    'refresh keeps the old figures while it works, then replaces them',
    build: bloc,
    seed: () => ActivityState(allowed: _allowed, reading: _reading),
    setUp: () => health.reading = ActivityReading(
      readAt: DateTime(2026, 10, 19, 22),
      steps: 6000,
    ),
    act: (bloc) => bloc.add(const ActivityRefreshRequested()),
    expect: () => [
      ActivityState(allowed: _allowed, reading: _reading, busy: true),
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
    'a sync that fails keeps the new reading and says so, and is not "synced"',
    build: bloc,
    setUp: () {
      runs.earliest = DateTime.utc(2026, 10, 15);
      runs.error = const RunsFailure(RunsFailureCode.network);
    },
    act: (bloc) => bloc.add(const ActivityStarted(_allowed)),
    expect: () => [
      const ActivityState(allowed: _allowed, busy: true),
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
    seed: () => ActivityState(
      allowed: _allowed,
      reading: _reading,
      syncedAt: _reading.readAt,
    ),
    setUp: () => health.readError = const HealthFailure(),
    act: (bloc) => bloc.add(const ActivityRefreshRequested()),
    expect: () => [
      ActivityState(
        allowed: _allowed,
        reading: _reading,
        syncedAt: _reading.readAt,
        busy: true,
      ),
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

  blocTest<ActivityBloc, ActivityState>(
    'a new refresh clears the error',
    build: bloc,
    seed: () => const ActivityState(allowed: _allowed, error: 'Nope'),
    act: (bloc) => bloc.add(const ActivityRefreshRequested()),
    expect: () => [
      const ActivityState(allowed: _allowed, busy: true),
      ActivityState(
        allowed: _allowed,
        reading: _reading,
        syncedAt: _reading.readAt,
      ),
    ],
  );
}

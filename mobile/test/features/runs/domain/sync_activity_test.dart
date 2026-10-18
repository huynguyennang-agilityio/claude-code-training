import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/usecases/sync_activity.dart';

import '../../../helpers/health_fixtures.dart';
import '../../../helpers/runs_fixtures.dart';

final _now = DateTime(2026, 10, 19, 21, 55);
final _joined = DateTime.utc(2026, 10, 15, 9);

StepRecord _record(String id) => StepRecord(
  id: id,
  startTime: DateTime.utc(2026, 10, 18, 6),
  endTime: DateTime.utc(2026, 10, 18, 7),
  steps: 100,
);

const _all = {
  HealthMetric.steps,
  HealthMetric.calories,
  HealthMetric.distance,
  HealthMetric.sleep,
};

void main() {
  late FakeHealthRepository health;
  late FakeRunsRepository runs;
  late SyncActivity sync;

  setUp(() {
    health = FakeHealthRepository();
    runs = FakeRunsRepository();
    sync = SyncActivity(health, runs);
  });

  Future<ActivitySync> run(Set<HealthMetric> allowed) =>
      sync(allowed, clock: () => _now);

  test('reads, sends the steps since the earliest join and the days', () async {
    runs.earliest = _joined;
    health
      ..records = [_record('a'), _record('b')]
      ..days = [DailyFigures(date: DateTime(2026, 10, 19), steps: 5490)];

    final result = await run(_all);

    expect(result.failure, isNull);
    expect(result.reading, health.reading);
    expect(health.stepsFrom, _joined);
    expect(runs.syncedRecords.single.map((r) => r.id), ['a', 'b']);
    expect(runs.savedDays.single.single.steps, 5490);
  });

  test('no active run challenge means no steps are read or sent', () async {
    runs.earliest = null;
    health.records = [_record('a')];

    await run(_all);

    expect(health.stepsFrom, isNull);
    expect(runs.syncedRecords, isEmpty);
    expect(runs.savedDays, hasLength(1));
  });

  test('a join long ago is read from at most 60 days back', () async {
    runs.earliest = DateTime(2026, 1, 1);
    health.records = [_record('a')];

    await run(_all);

    expect(health.stepsFrom, _now.subtract(SyncActivity.maxStepWindow));
  });

  test(
    'without steps allowed nothing is read or sent for challenges',
    () async {
      runs.earliest = _joined;

      await run({HealthMetric.calories});

      expect(runs.earliestCalls, 0);
      expect(runs.syncedRecords, isEmpty);
      expect(runs.savedDays, hasLength(1));
    },
  );

  test('no step records means no step request', () async {
    runs.earliest = _joined;
    health.records = const [];

    await run(_all);

    expect(runs.syncedRecords, isEmpty);
  });

  test('a backend failure still returns what was read', () async {
    runs.earliest = _joined;
    runs.error = const RunsFailure(RunsFailureCode.network);

    final result = await run(_all);

    expect(result.reading, health.reading);
    expect(result.failure, const RunsFailure(RunsFailureCode.network));
    expect(runs.savedDays, isEmpty);
  });

  test('a health read failure is thrown, and nothing is sent', () async {
    health.readError = const HealthFailure();

    await expectLater(run(_all), throwsA(isA<HealthFailure>()));

    expect(runs.earliestCalls, 0);
    expect(runs.savedDays, isEmpty);
  });
}

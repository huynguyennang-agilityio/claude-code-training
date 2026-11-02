import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/usecases/get_health_notice.dart';

import '../../../helpers/health_fixtures.dart';
import '../../../helpers/runs_fixtures.dart';

final _now = DateTime.utc(2026, 10, 19, 12);

const _unconfirmed = HealthAccess(
  HealthAccessStatus.granted,
  allowed: {HealthMetric.steps},
  confirmed: false,
);

List<DailyFigures> _days(List<int?> steps) => [
  for (var i = 0; i < steps.length; i++)
    DailyFigures(date: DateTime(2026, 10, 17 + i), steps: steps[i]),
];

void main() {
  late FakeHealthRepository health;
  late FakeRunsRepository runs;
  late GetHealthNotice getNotice;

  setUp(() {
    health = FakeHealthRepository();
    runs = FakeRunsRepository();
    getNotice = GetHealthNotice(health, runs);
  });

  Future<HealthNotice> notice() => getNotice(clock: () => _now);

  test('unavailable is install', () async {
    health.access = const HealthAccess.unavailable();
    expect(await notice(), HealthNotice.install);
  });

  test('permanently denied is settings', () async {
    health.access = const HealthAccess.permanentlyDenied();
    expect(await notice(), HealthNotice.settings);
  });

  test('denied is askable', () async {
    health.access = const HealthAccess.denied();
    expect(await notice(), HealthNotice.askable);
  });

  test('confirmed granted is none, and nothing else is read', () async {
    expect(await notice(), HealthNotice.none);
    expect(runs.countingCalls, 0);
    expect(health.readDaysCalls, 0);
  });

  group('granted but unconfirmed', () {
    setUp(() {
      health.access = _unconfirmed;
      runs.counting = _now.subtract(GetHealthNotice.quietSpan);
      health.days = _days([0, 0, 0]);
    });

    test('with no active enrollment is none', () async {
      runs.counting = null;
      expect(await notice(), HealthNotice.none);
      expect(health.readDaysCalls, 0);
    });

    test('counting for less than 3 days is none', () async {
      runs.counting = _now.subtract(
        GetHealthNotice.quietSpan - const Duration(minutes: 1),
      );
      expect(await notice(), HealthNotice.none);
      expect(health.readDaysCalls, 0);
    });

    test('counting for 3 days with three 0-step days is noSteps', () async {
      expect(await notice(), HealthNotice.noSteps);
      expect(health.lastReadDays?.allowed, {HealthMetric.steps});
      expect(health.lastReadDays?.days, GetHealthNotice.quietDays);
    });

    test('one day with steps is none', () async {
      health.days = _days([0, 12, 0]);
      expect(await notice(), HealthNotice.none);
    });

    test('null steps count as 0', () async {
      health.days = _days([null, 0, null]);
      expect(await notice(), HealthNotice.noSteps);
    });

    test('fewer days than asked for is none', () async {
      health.days = _days([0, 0]);
      expect(await notice(), HealthNotice.none);
    });

    test('a challenge that starts later is none', () async {
      runs.counting = _now.add(const Duration(days: 2));
      expect(await notice(), HealthNotice.none);
      expect(health.readDaysCalls, 0);
    });

    test('a RunsFailure is none', () async {
      runs.error = const RunsFailure(RunsFailureCode.network);
      expect(await notice(), HealthNotice.none);
    });

    test('a HealthFailure from readDays is none', () async {
      health.readDaysError = const HealthFailure();
      expect(await notice(), HealthNotice.none);
    });
  });
}

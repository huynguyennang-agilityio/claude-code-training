import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/usecases/sync_activity.dart';

import '../../../helpers/health_fixtures.dart';
import '../../../helpers/runs_fixtures.dart';

final _now = DateTime(2026, 10, 19, 21, 55);
final _joined = DateTime.utc(2026, 9, 1, 9);
const _network = RunsFailure(RunsFailureCode.network);

const _all = {
  HealthMetric.steps,
  HealthMetric.calories,
  HealthMetric.distance,
  HealthMetric.sleep,
};

final _hour = StepHour(hourStart: DateTime.utc(2026, 10, 18, 6), steps: 100);

List<DailyFigures> _days(int count) => [
  for (var i = 0; i < count; i++)
    DailyFigures(date: DateTime(2026, 10, 19 - count + 1 + i), steps: i),
];

void main() {
  late FakeHealthRepository health;
  late FakeRunsRepository runs;
  late FakeSyncStateRepository state;
  late SyncActivity sync;

  setUp(() {
    health = FakeHealthRepository()..hours = [_hour];
    runs = FakeRunsRepository()..earliest = _joined;
    state = FakeSyncStateRepository()..first = DateTime(2026, 9);
    sync = SyncActivity(health, runs, state);
  });

  Future<ActivitySync> run([Set<HealthMetric> allowed = _all]) =>
      sync(allowed, clock: () => _now);

  test(
    'reads, sends the hours and the days, and moves the watermark',
    () async {
      state.stored = _now.subtract(const Duration(hours: 1));
      health.days = _days(3);

      final result = await run();

      expect(result.failure, isNull);
      expect(result.reading, health.reading);
      expect(runs.syncedHours.single, [_hour]);
      expect(runs.savedDays.single, health.days);
      expect(state.stored, _now);
    },
  );

  group('window of the step hours', () {
    test('an app left for 3 days reads from the watermark minus 48h', () async {
      final watermark = _now.subtract(const Duration(days: 3));
      state.stored = watermark;

      await run();

      expect(health.hoursRead, (
        from: watermark.subtract(const Duration(hours: 48)),
        to: _now,
      ));
    });

    test('no watermark reads 30 days', () async {
      await run();

      expect(health.hoursRead, (
        from: _now.subtract(const Duration(days: 30)),
        to: _now,
      ));
    });

    test('no watermark is clamped by the earliest join', () async {
      runs.earliest = DateTime.utc(2026, 10, 15, 9);

      await run();

      expect(health.hoursRead?.from, DateTime.utc(2026, 10, 15, 9));
    });

    test(
      'a watermark minus 48h earlier than the join reads from the join',
      () async {
        runs.earliest = DateTime.utc(2026, 10, 1, 9);
        state.stored = DateTime.utc(2026, 10, 1, 12);

        await run();

        expect(health.hoursRead?.from, DateTime.utc(2026, 10, 1, 9));
      },
    );

    test('more than 30 days since the watermark reads 30 days', () async {
      state.stored = _now.subtract(const Duration(days: 45));

      await run();

      expect(health.hoursRead?.from, _now.subtract(const Duration(days: 30)));
    });

    test('a join long ago does not read beyond 30 days', () async {
      runs.earliest = DateTime(2026, 1, 1);

      await run();

      expect(health.hoursRead?.from, _now.subtract(const Duration(days: 30)));
    });

    test(
      'no active run reads and sends no hours, but sends the days',
      () async {
        runs.earliest = null;
        health.days = _days(2);

        await run();

        expect(health.hoursRead, isNull);
        expect(runs.syncedHours, isEmpty);
        expect(runs.savedDays, hasLength(1));
        expect(state.stored, _now);
      },
    );

    test('no hours means no request', () async {
      health.hours = const [];

      await run();

      expect(runs.syncedHours, isEmpty);
    });

    test('without steps allowed no hours are read or sent', () async {
      health.days = _days(1);

      await run({HealthMetric.calories});

      expect(runs.earliestCalls, 0);
      expect(health.hoursRead, isNull);
      expect(runs.syncedHours, isEmpty);
      expect(runs.savedDays, hasLength(1));
    });

    test('without steps allowed the watermark does not move', () async {
      final watermark = _now.subtract(const Duration(days: 40));
      state.stored = watermark;

      final result = await run({HealthMetric.calories});

      expect(result.failure, isNull);
      expect(state.stored, watermark);
    });

    test('turning steps on later catches up 30 days', () async {
      await run({HealthMetric.calories});
      expect(state.stored, isNull);

      await run();

      expect(health.hoursRead, (
        from: _now.subtract(const Duration(days: 30)),
        to: _now,
      ));
      expect(state.stored, _now);
    });
  });

  group('daily figures', () {
    test(
      'cover each day from 48h before the watermark through today',
      () async {
        state.stored = _now.subtract(const Duration(days: 3));
        health.days = _days(6);

        await run();

        // The window starts on Oct 14: six calendar days up to Oct 19.
        expect(health.lastReadDays?.days, 6);
        expect(health.lastReadDays?.allowed, _all);
      },
    );

    test('with no watermark cover 30 days, in one call', () async {
      health.days = _days(31);

      await run();

      expect(health.lastReadDays?.days, 31);
      expect(runs.savedDays.single, health.days);
    });

    test('do not start before the first sync', () async {
      state.first = DateTime(2026, 10, 17, 8);
      health.days = _days(3);

      await run();

      expect(health.lastReadDays?.days, 3);
    });

    test('the first sync records its time', () async {
      state.first = null;

      await run();

      expect(state.first, _now);
      expect(health.lastReadDays?.days, 1);
    });
  });

  group('failures', () {
    test('an error on the second request keeps the watermark', () async {
      final watermark = _now.subtract(const Duration(days: 20));
      state.stored = watermark;
      health.days = _days(10);
      runs
        ..error = _network
        ..failDaysCall = 1;

      final result = await run();

      expect(result.reading, health.reading);
      expect(result.failure, _network);
      expect(runs.syncedHours, hasLength(1));
      expect(runs.savedDays, isEmpty);
      expect(state.stored, watermark);
    });

    test(
      'a failing hours request keeps the watermark and sends no days',
      () async {
        runs.error = _network;

        final result = await run();

        expect(result.failure, _network);
        expect(runs.savedDays, isEmpty);
        expect(state.stored, isNull);
      },
    );

    test('a health read failure is thrown, and nothing is sent', () async {
      health.readError = const HealthFailure();

      await expectLater(run(), throwsA(isA<HealthFailure>()));

      expect(runs.earliestCalls, 0);
      expect(runs.savedDays, isEmpty);
      expect(state.stored, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/runs/data/repositories/health_repository_impl.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';

import '../../../helpers/health_fixtures.dart';

const _all = {
  HealthMetric.steps,
  HealthMetric.calories,
  HealthMetric.distance,
  HealthMetric.sleep,
};

void main() {
  late FakeHealthDataSource source;
  late InMemoryHealthPromptStore prompts;
  late HealthRepositoryImpl repository;

  setUp(() {
    source = FakeHealthDataSource();
    prompts = InMemoryHealthPromptStore();
    repository = HealthRepositoryImpl(source, prompts);
  });

  group('Android, which says what is allowed', () {
    setUp(() => source.allowed = {});

    test(
      'Health Connect missing is unavailable, and nothing is asked',
      () async {
        source.available = false;

        expect(
          await repository.checkAccess(),
          const HealthAccess.unavailable(),
        );
        expect(
          await repository.requestAccess(),
          const HealthAccess.unavailable(),
        );
        expect(source.requests, 0);
      },
    );

    test(
      'steps allowed is granted, with the metrics that are allowed',
      () async {
        source.allowed = {HealthMetric.steps, HealthMetric.sleep};

        final access = await repository.checkAccess();

        expect(access.status, HealthAccessStatus.granted);
        expect(access.allowed, {HealthMetric.steps, HealthMetric.sleep});
      },
    );

    test('optional metrics without steps are still denied', () async {
      source.allowed = {HealthMetric.calories};

      expect(
        (await repository.checkAccess()).status,
        HealthAccessStatus.denied,
      );
    });

    test('nothing allowed and never asked is denied', () async {
      expect(await repository.checkAccess(), const HealthAccess.denied());
    });

    test('allowing in the dialog is granted, and the ask is counted', () async {
      source.grantsOnRequest = _all;

      final access = await repository.requestAccess();

      expect(access.status, HealthAccessStatus.granted);
      expect(access.allowed, _all);
      expect(prompts.count, 1);
    });

    test('refusing once is denied, refusing twice is permanent', () async {
      expect(await repository.requestAccess(), const HealthAccess.denied());
      expect(
        await repository.requestAccess(),
        const HealthAccess.permanentlyDenied(),
      );
      expect(prompts.count, 2);
    });

    test('checking access does not ask, and does not count', () async {
      await repository.checkAccess();

      expect(source.requests, 0);
      expect(prompts.count, 0);
    });

    test(
      'a dialog that could not be shown is denied and not counted',
      () async {
        source.dialogShown = false;

        expect(await repository.requestAccess(), const HealthAccess.denied());
        expect(prompts.count, 0);
      },
    );

    test('allowed in Settings after a refusal is granted again', () async {
      await repository.requestAccess();
      await repository.requestAccess();
      source.allowed = {HealthMetric.steps};

      expect(
        (await repository.checkAccess()).status,
        HealthAccessStatus.granted,
      );
    });
  });

  group('iOS, which hides whether a read was refused', () {
    test('before the dialog was shown it is denied', () async {
      expect(await repository.checkAccess(), const HealthAccess.denied());
    });

    test(
      'once the dialog was shown it is granted, with every metric',
      () async {
        final access = await repository.requestAccess();

        expect(access.status, HealthAccessStatus.granted);
        expect(access.allowed, _all);
        expect(prompts.count, 1);
      },
    );

    test('and stays granted on the next launch', () async {
      prompts.count = 1;

      expect(
        (await repository.checkAccess()).status,
        HealthAccessStatus.granted,
      );
    });

    test('a dialog that could not be shown leaves it denied', () async {
      source.dialogShown = false;

      expect(await repository.requestAccess(), const HealthAccess.denied());
      expect(prompts.count, 0);
    });
  });

  group('reading', () {
    final now = DateTime(2026, 10, 19, 21, 55);
    late HealthRepositoryImpl reader;

    setUp(() {
      reader = HealthRepositoryImpl(source, prompts, clock: () => now);
      source.totals.addAll({
        HealthMetric.steps: 5490,
        HealthMetric.calories: 312,
        HealthMetric.distance: 3080,
        HealthMetric.sleep: 390,
      });
    });

    test('today is read from midnight, for the allowed metrics only', () async {
      final reading = await reader.readToday({
        HealthMetric.steps,
        HealthMetric.distance,
      });

      expect(reading.readAt, now);
      expect((reading.steps, reading.distanceM), (5490, 3080));
      expect((reading.calories, reading.sleepMinutes), (null, null));
      expect(source.totalCalls.map((c) => c.$1), [
        HealthMetric.steps,
        HealthMetric.distance,
      ]);
      expect(source.totalCalls.first.$2, DateTime(2026, 10, 19));
      expect(source.totalCalls.first.$3, now);
    });

    test('sleep is the night that ends today, from 18:00 yesterday', () async {
      await reader.readToday({HealthMetric.sleep});

      expect(source.totalCalls.single.$2, DateTime(2026, 10, 18, 18));
    });

    test('a read that throws is a HealthFailure', () async {
      source.readError = Exception('no access');

      await expectLater(reader.readToday(_all), throwsA(isA<HealthFailure>()));
    });

    test('days are calendar dates, today last and up to now', () async {
      final days = await reader.readDays({HealthMetric.steps}, days: 2);

      expect(days.map((d) => d.date), [
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 19),
      ]);
      expect(days.first.steps, 5490);
      expect(days.first.calories, isNull);
      final yesterday = source.totalCalls[0];
      expect(
        (yesterday.$2, yesterday.$3),
        (DateTime(2026, 10, 18), DateTime(2026, 10, 19)),
      );
      expect(source.totalCalls[1].$3, now);
    });

    test('step records come from the source up to now', () async {
      source.records = [
        StepRecord(
          id: 'a',
          startTime: DateTime.utc(2026, 10, 18, 6),
          endTime: DateTime.utc(2026, 10, 18, 7),
          steps: 100,
        ),
      ];

      final records = await reader.readStepRecords(
        from: DateTime(2026, 10, 15),
      );

      expect(records.single.id, 'a');
      expect(
        (source.recordsFrom, source.recordsTo),
        (DateTime(2026, 10, 15), now),
      );
    });
  });

  test('settings and the Health Connect install go to the source', () async {
    await repository.openSettings();
    await repository.installHealthConnect();

    expect((source.settingsOpened, source.installs), (1, 1));
  });
}

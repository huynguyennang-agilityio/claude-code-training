import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/runs/data/datasources/health_data_source.dart';
import 'package:stridequest/features/runs/data/repositories/health_repository_impl.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';

import '../../../helpers/health_fixtures.dart';

class _MockHealth extends Mock implements Health {}

HealthDataPoint _point(
  String source,
  DateTime from,
  DateTime to,
  num steps, {
  String? id,
}) => HealthDataPoint(
  uuid: id ?? '$source-$from',
  value: NumericHealthValue(numericValue: steps),
  type: HealthDataType.STEPS,
  unit: HealthDataUnit.COUNT,
  dateFrom: from,
  dateTo: to,
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: source,
  sourceName: source,
);

StepHour _hour(int day, int hour, int steps) =>
    StepHour(hourStart: DateTime.utc(2026, 10, day, hour), steps: steps);

void main() {
  late _MockHealth health;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(HealthDataType.STEPS);
    registerFallbackValue(RecordingMethod.manual);
  });

  setUp(() {
    health = _MockHealth();
    when(
      () => health.removeDuplicates(any()),
    ).thenAnswer((i) => i.positionalArguments.first as List<HealthDataPoint>);
  });

  void stubAndroid(List<HealthDataPoint> points) {
    when(
      () => health.getHealthDataFromTypes(
        types: any(named: 'types'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        recordingMethodsToFilter: any(named: 'recordingMethodsToFilter'),
      ),
    ).thenAnswer((_) async => points);
  }

  PluginHealthDataSource android() =>
      PluginHealthDataSource(health: health, ios: false);

  group('Android', () {
    test('two overlapping sources in one hour give the larger total', () async {
      stubAndroid([
        _point(
          'watch',
          DateTime.utc(2026, 10, 19, 8, 0),
          DateTime.utc(2026, 10, 19, 8, 20),
          600,
        ),
        _point(
          'watch',
          DateTime.utc(2026, 10, 19, 8, 20),
          DateTime.utc(2026, 10, 19, 8, 40),
          500,
        ),
        _point(
          'phone',
          DateTime.utc(2026, 10, 19, 8, 0),
          DateTime.utc(2026, 10, 19, 8, 59),
          900,
        ),
      ]);

      final hours = await android().stepHours(
        DateTime.utc(2026, 10, 19, 8),
        DateTime.utc(2026, 10, 19, 9),
      );

      expect(hours, [_hour(19, 8, 1100)]);
    });

    test('manual entries are filtered out by the read', () async {
      stubAndroid([]);

      await android().stepHours(
        DateTime.utc(2026, 10, 19, 8),
        DateTime.utc(2026, 10, 19, 9),
      );

      verify(
        () => health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: DateTime.utc(2026, 10, 19, 8),
          endTime: DateTime.utc(2026, 10, 19, 9),
          recordingMethodsToFilter: [RecordingMethod.manual],
        ),
      ).called(1);
    });

    test('hours without steps are left out and the rest is ordered', () async {
      stubAndroid([
        _point(
          'a',
          DateTime.utc(2026, 10, 19, 11, 5),
          DateTime.utc(2026, 10, 19, 11, 10),
          40,
        ),
        _point(
          'a',
          DateTime.utc(2026, 10, 19, 9, 5),
          DateTime.utc(2026, 10, 19, 9, 10),
          0,
        ),
        _point(
          'a',
          DateTime.utc(2026, 10, 19, 8, 5),
          DateTime.utc(2026, 10, 19, 8, 10),
          30,
        ),
      ]);

      final hours = await android().stepHours(
        DateTime.utc(2026, 10, 19, 8),
        DateTime.utc(2026, 10, 19, 12),
      );

      expect(hours, [_hour(19, 8, 30), _hour(19, 11, 40)]);
    });

    test('a record crossing an hour is split by time overlap', () async {
      stubAndroid([
        _point(
          'a',
          DateTime.utc(2026, 10, 19, 8, 45),
          DateTime.utc(2026, 10, 19, 9, 15),
          100,
        ),
      ]);

      final hours = await android().stepHours(
        DateTime.utc(2026, 10, 19, 8),
        DateTime.utc(2026, 10, 19, 10),
      );

      expect(hours, [_hour(19, 8, 50), _hour(19, 9, 50)]);
    });

    test('rounding happens once per hour, not per piece', () async {
      // Each record puts 0.4 step in each hour: 0.8 per hour rounds to 1,
      // where rounding every piece first would give 0.
      final hours = stepHoursFromSlices(
        [
          (
            source: 'a',
            from: DateTime.utc(2026, 10, 19, 8, 30),
            to: DateTime.utc(2026, 10, 19, 9, 30),
            steps: 0.8,
          ),
          (
            source: 'a',
            from: DateTime.utc(2026, 10, 19, 8, 30),
            to: DateTime.utc(2026, 10, 19, 9, 30),
            steps: 0.8,
          ),
        ],
        from: DateTime.utc(2026, 10, 19, 8),
        to: DateTime.utc(2026, 10, 19, 10),
      );

      expect(hours, [_hour(19, 8, 1), _hour(19, 9, 1)]);
    });

    test('from is floored to its hour and to is exclusive', () async {
      stubAndroid([
        _point(
          'a',
          DateTime.utc(2026, 10, 19, 8, 0),
          DateTime.utc(2026, 10, 19, 8, 5),
          10,
        ),
        _point(
          'a',
          DateTime.utc(2026, 10, 19, 9, 0),
          DateTime.utc(2026, 10, 19, 9, 5),
          20,
        ),
        _point(
          'a',
          DateTime.utc(2026, 10, 19, 10, 0),
          DateTime.utc(2026, 10, 19, 10, 5),
          30,
        ),
      ]);

      final hours = await android().stepHours(
        DateTime.utc(2026, 10, 19, 8, 40),
        DateTime.utc(2026, 10, 19, 10),
      );

      expect(hours, [_hour(19, 8, 10), _hour(19, 9, 20)]);
      verify(
        () => health.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: DateTime.utc(2026, 10, 19, 8),
          endTime: any(named: 'endTime'),
          recordingMethodsToFilter: any(named: 'recordingMethodsToFilter'),
        ),
      ).called(1);
    });

    test('a local from still yields UTC hour starts', () async {
      stubAndroid([
        _point(
          'a',
          DateTime.utc(2026, 10, 19, 8, 5),
          DateTime.utc(2026, 10, 19, 8, 10),
          10,
        ),
      ]);

      final hours = await android().stepHours(
        DateTime(2026, 10, 19, 8, 30),
        DateTime(2026, 10, 19, 23),
      );

      expect(hours.every((h) => h.hourStart.isUtc), isTrue);
      expect(hours.every((h) => h.hourStart.minute == 0), isTrue);
    });

    test('a failing read throws and the repository wraps it', () async {
      when(
        () => health.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
          recordingMethodsToFilter: any(named: 'recordingMethodsToFilter'),
        ),
      ).thenThrow(Exception('boom'));
      final repository = HealthRepositoryImpl(
        android(),
        InMemoryHealthPromptStore(),
      );

      await expectLater(
        repository.readStepHours(
          from: DateTime.utc(2026, 10, 19),
          to: DateTime.utc(2026, 10, 20),
        ),
        throwsA(isA<HealthFailure>()),
      );
    });

    test(
      'a day with a manual entry equals the sum of its hours',
      () async {
        // The plugin drops the manual record, as the filter asks.
        final records = [
          _point(
            'a',
            DateTime.utc(2026, 10, 19, 6, 10),
            DateTime.utc(2026, 10, 19, 6, 40),
            300,
          ),
          _point(
            'b',
            DateTime.utc(2026, 10, 19, 6, 0),
            DateTime.utc(2026, 10, 19, 6, 50),
            280,
          ),
          _point(
            'a',
            DateTime.utc(2026, 10, 19, 13, 0),
            DateTime.utc(2026, 10, 19, 13, 30),
            700,
          ),
        ];
        final manual = _point(
          'm',
          DateTime.utc(2026, 10, 19, 7),
          DateTime.utc(2026, 10, 19, 7, 1),
          9999,
        );
        when(
          () => health.getHealthDataFromTypes(
            types: any(named: 'types'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
            recordingMethodsToFilter: any(named: 'recordingMethodsToFilter'),
          ),
        ).thenAnswer((i) async {
          final filter = i.namedArguments[#recordingMethodsToFilter] as List;
          return [...records, if (filter.isEmpty) manual];
        });
        final source = android();
        final now = DateTime.utc(2026, 10, 19, 20);
        final repository = HealthRepositoryImpl(
          source,
          InMemoryHealthPromptStore(),
          clock: () => now,
        );

        final hours = await repository.readStepHours(
          from: DateTime.utc(2026, 10, 19),
          to: now,
        );
        final days = await repository.readDays({HealthMetric.steps}, days: 1);

        expect(hours, [_hour(19, 6, 300), _hour(19, 13, 700)]);
        expect(days.single.steps, 1000);
      },
      skip: DateTime.now().timeZoneOffset.inMinutes % 60 != 0
          ? 'needs a whole-hour time zone'
          : false,
    );
  });

  group('iOS', () {
    test('maps each hourly bucket to its start and skips empty ones', () async {
      final start = DateTime.utc(2026, 10, 19, 8);
      when(
        () => health.getHealthIntervalDataFromTypes(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          types: any(named: 'types'),
          interval: any(named: 'interval'),
          recordingMethodsToFilter: any(named: 'recordingMethodsToFilter'),
        ),
      ).thenAnswer(
        (_) async => [
          _point(
            'hk',
            start.add(const Duration(hours: 2)),
            start.add(const Duration(hours: 3)),
            120.4,
          ),
          _point('hk', start, start.add(const Duration(hours: 1)), 80.6),
          _point(
            'hk',
            start.add(const Duration(hours: 1)),
            start.add(const Duration(hours: 2)),
            0.2,
          ),
        ],
      );

      final hours = await PluginHealthDataSource(health: health, ios: true)
          .stepHours(
            DateTime.utc(2026, 10, 19, 8, 30),
            DateTime.utc(2026, 10, 19, 11),
          );

      expect(hours, [_hour(19, 8, 81), _hour(19, 10, 120)]);
      verify(
        () => health.getHealthIntervalDataFromTypes(
          startDate: DateTime.utc(2026, 10, 19, 8),
          endDate: DateTime.utc(2026, 10, 19, 11),
          types: [HealthDataType.STEPS],
          interval: 3600,
          recordingMethodsToFilter: [RecordingMethod.manual],
        ),
      ).called(1);
      verifyNever(() => health.getTotalStepsInInterval(any(), any()));
    });
  });
}

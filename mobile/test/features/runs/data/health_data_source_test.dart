import 'package:flutter/services.dart';
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

/// A point as the plugin builds it on Android: `sourceId` empty and the app's
/// package in `sourceName`.
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
  sourceId: '',
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

    test('records are clipped to the exact bounds', () async {
      final hours = stepHoursFromSlices(
        [
          (
            source: 'a',
            from: DateTime.utc(2026, 10, 19, 8, 0),
            to: DateTime.utc(2026, 10, 19, 10, 0),
            steps: 200,
          ),
        ],
        from: DateTime.utc(2026, 10, 19, 8, 30),
        to: DateTime.utc(2026, 10, 19, 9, 30),
      );

      expect(hours, [_hour(19, 8, 50), _hour(19, 9, 50)]);
    });

    test('a split hour takes the same source on both sides', () async {
      // Source a walks before 18:30Z and source b after it: the whole hour
      // has 60 from either, so the two days must add up to 60, not 120.
      final slices = <StepSlice>[
        (
          source: 'a',
          from: DateTime.utc(2026, 10, 19, 18),
          to: DateTime.utc(2026, 10, 19, 18, 30),
          steps: 60,
        ),
        (
          source: 'b',
          from: DateTime.utc(2026, 10, 19, 18, 30),
          to: DateTime.utc(2026, 10, 19, 19),
          steps: 50,
        ),
      ];
      final middle = DateTime.utc(2026, 10, 19, 18, 30);

      final first = stepHoursFromSlices(
        slices,
        from: DateTime.utc(2026, 10, 18, 18, 30),
        to: middle,
      );
      final second = stepHoursFromSlices(
        slices,
        from: middle,
        to: DateTime.utc(2026, 10, 20, 18, 30),
      );

      expect(first, [_hour(19, 18, 60)]);
      expect(second, isEmpty);
    });

    test('a split hour with equal sources takes the first name', () async {
      // Both sources have 60 in the whole hour; the tie goes to `a` on both
      // sides of the 18:30Z day boundary, so the days add up to 60, not 120.
      final slices = <StepSlice>[
        (
          source: 'a',
          from: DateTime.utc(2026, 10, 19, 18),
          to: DateTime.utc(2026, 10, 19, 18, 30),
          steps: 60,
        ),
        (
          source: 'b',
          from: DateTime.utc(2026, 10, 19, 18, 30),
          to: DateTime.utc(2026, 10, 19, 19),
          steps: 60,
        ),
      ];
      final middle = DateTime.utc(2026, 10, 19, 18, 30);

      final first = stepHoursFromSlices(
        slices,
        from: DateTime.utc(2026, 10, 18, 18, 30),
        to: middle,
      );
      final second = stepHoursFromSlices(
        slices,
        from: middle,
        to: DateTime.utc(2026, 10, 20, 18, 30),
      );
      final whole = stepHoursFromSlices(
        slices,
        from: DateTime.utc(2026, 10, 18, 18, 30),
        to: DateTime.utc(2026, 10, 20, 18, 30),
      );

      expect(first, [_hour(19, 18, 60)]);
      expect(second, isEmpty);
      expect(whole, [_hour(19, 18, 60)]);
      final sum = [...first, ...second].fold<int>(0, (s, h) => s + h.steps);
      expect(sum, 60);
    });

    test('a tie in one range takes the first name, not the most inside', () {
      // Equal 60 in the whole hour. `z` comes first in the input and has more
      // steps inside [18:00Z, 18:30Z); `b` sorts first and must still win.
      final slices = <StepSlice>[
        (
          source: 'z',
          from: DateTime.utc(2026, 10, 19, 18),
          to: DateTime.utc(2026, 10, 19, 18, 30),
          steps: 60,
        ),
        (
          source: 'b',
          from: DateTime.utc(2026, 10, 19, 18, 30),
          to: DateTime.utc(2026, 10, 19, 19),
          steps: 60,
        ),
      ];

      final before = stepHoursFromSlices(
        slices,
        from: DateTime.utc(2026, 10, 19, 18),
        to: DateTime.utc(2026, 10, 19, 18, 30),
      );
      final after = stepHoursFromSlices(
        slices,
        from: DateTime.utc(2026, 10, 19, 18, 30),
        to: DateTime.utc(2026, 10, 19, 19),
      );

      expect(before, isEmpty);
      expect(after, [_hour(19, 18, 60)]);
    });

    test('equal totals with float noise still tie by name', () {
      // Exactly 66.8666… each: `b` as 5 + 64 × 29/30, `a` as 68 × 59/60. As
      // doubles `b` is one ulp larger, but `a` sorts first and must win.
      final hours = stepHoursFromSlices(
        [
          (
            source: 'b',
            from: DateTime.utc(2026, 10, 19, 18, 1),
            to: DateTime.utc(2026, 10, 19, 18, 31),
            steps: 5,
          ),
          (
            source: 'b',
            from: DateTime.utc(2026, 10, 19, 18, 31),
            to: DateTime.utc(2026, 10, 19, 19, 1),
            steps: 64,
          ),
          (
            source: 'a',
            from: DateTime.utc(2026, 10, 19, 18, 1),
            to: DateTime.utc(2026, 10, 19, 19, 1),
            steps: 68,
          ),
        ],
        from: DateTime.utc(2026, 10, 19, 18),
        to: DateTime.utc(2026, 10, 19, 18, 31),
      );

      expect(hours, [_hour(19, 18, 34)]);
    });

    test('adjacent days with half-hour bounds count no hour twice', () async {
      final slices = <StepSlice>[
        (
          source: 'a',
          from: DateTime.utc(2026, 10, 19, 10),
          to: DateTime.utc(2026, 10, 19, 11),
          steps: 60,
        ),
        // Crosses the day boundary at 18:30Z, in the middle of an hour.
        (
          source: 'a',
          from: DateTime.utc(2026, 10, 19, 18),
          to: DateTime.utc(2026, 10, 19, 19),
          steps: 100,
        ),
        (
          source: 'b',
          from: DateTime.utc(2026, 10, 19, 18, 10),
          to: DateTime.utc(2026, 10, 19, 18, 50),
          steps: 80,
        ),
        (
          source: 'a',
          from: DateTime.utc(2026, 10, 20, 5),
          to: DateTime.utc(2026, 10, 20, 6),
          steps: 40,
        ),
      ];
      int sum(List<StepHour> hours) =>
          hours.fold<int>(0, (total, h) => total + h.steps);
      final start = DateTime.utc(2026, 10, 18, 18, 30);
      final middle = DateTime.utc(2026, 10, 19, 18, 30);
      final end = DateTime.utc(2026, 10, 20, 18, 30);

      final first = stepHoursFromSlices(slices, from: start, to: middle);
      final second = stepHoursFromSlices(slices, from: middle, to: end);
      final whole = stepHoursFromSlices(slices, from: start, to: end);

      expect(first, [_hour(19, 10, 60), _hour(19, 18, 50)]);
      expect(second, [_hour(19, 18, 50), _hour(20, 5, 40)]);
      expect(sum(first) + sum(second), sum(whole));
      expect(sum(whole), 200);
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
      final from = DateTime(2026, 10, 19, 8, 30);
      final utc = from.toUtc();
      final hour = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
      stubAndroid([
        _point(
          'a',
          hour.add(const Duration(minutes: 5)),
          hour.add(const Duration(minutes: 10)),
          10,
        ),
      ]);

      final hours = await android().stepHours(from, DateTime(2026, 10, 19, 23));

      expect(hours, [StepHour(hourStart: hour, steps: 10)]);
      expect(hours.single.hourStart.isUtc, isTrue);
    });

    test('steps are not read through total', () async {
      await expectLater(
        android().total(
          HealthMetric.steps,
          DateTime.utc(2026, 10, 19),
          DateTime.utc(2026, 10, 20),
        ),
        throwsArgumentError,
      );
      verifyNever(
        () => health.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
          recordingMethodsToFilter: any(named: 'recordingMethodsToFilter'),
        ),
      );
    });

    test('stepTotal over whole hours equals the sum of stepHours', () async {
      stubAndroid([
        _point(
          'watch',
          DateTime.utc(2026, 10, 19, 8, 45),
          DateTime.utc(2026, 10, 19, 9, 15),
          100,
        ),
        _point(
          'phone',
          DateTime.utc(2026, 10, 19, 9, 0),
          DateTime.utc(2026, 10, 19, 9, 50),
          70,
        ),
        _point(
          'phone',
          DateTime.utc(2026, 10, 19, 12, 0),
          DateTime.utc(2026, 10, 19, 12, 10),
          33,
        ),
      ]);
      final from = DateTime.utc(2026, 10, 19, 8);
      final to = DateTime.utc(2026, 10, 19, 12);

      final hours = await android().stepHours(from, to);
      final total = await android().stepTotal(from, to);

      expect(hours.fold<int>(0, (sum, h) => sum + h.steps), 120);
      expect(total, 120);
    });

    test('stepTotal reads the whole hours its bounds touch', () async {
      stubAndroid([]);

      await android().stepTotal(
        DateTime.utc(2026, 10, 19, 8, 30),
        DateTime.utc(2026, 10, 20, 8, 30),
      );

      verify(
        () => health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: DateTime.utc(2026, 10, 19, 8),
          endTime: DateTime.utc(2026, 10, 20, 9),
          recordingMethodsToFilter: [RecordingMethod.manual],
        ),
      ).called(1);
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
        // Record times are those of the local day, so the test holds in any
        // whole-hour time zone. The plugin drops the manual record, as the
        // filter asks.
        DateTime at(int hour, [int minute = 0]) =>
            DateTime(2026, 10, 19, hour, minute).toUtc();
        final records = [
          _point('a', at(6, 10), at(6, 40), 300),
          _point('b', at(6), at(6, 50), 280),
          _point('a', at(13), at(13, 30), 700),
        ];
        final manual = _point('m', at(7), at(7, 1), 9999);
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
        final now = DateTime(2026, 10, 19, 20);
        final repository = HealthRepositoryImpl(
          android(),
          InMemoryHealthPromptStore(),
          clock: () => now,
        );

        final hours = await repository.readStepHours(
          from: DateTime(2026, 10, 19),
          to: now,
        );
        final days = await repository.readDays({HealthMetric.steps}, days: 1);

        expect(hours, [
          StepHour(hourStart: at(6), steps: 300),
          StepHour(hourStart: at(13), steps: 700),
        ]);
        expect(days.single.steps, hours.fold<int>(0, (s, h) => s + h.steps));
        expect(days.single.steps, 1000);
      },
      skip: DateTime.now().timeZoneOffset.inMinutes % 60 != 0
          ? 'needs a whole-hour time zone'
          : false,
    );

    test('two sources are told apart by sourceName, not sourceId', () async {
      // Health Connect leaves sourceId empty for every record.
      final points = [
        _point(
          'watch',
          DateTime.utc(2026, 10, 19, 8),
          DateTime.utc(2026, 10, 19, 8, 30),
          400,
        ),
        _point(
          'phone',
          DateTime.utc(2026, 10, 19, 8),
          DateTime.utc(2026, 10, 19, 8, 30),
          350,
        ),
      ];
      expect(points.map((p) => p.sourceId), ['', '']);
      stubAndroid(points);

      final total = await android().stepTotal(
        DateTime.utc(2026, 10, 19, 8),
        DateTime.utc(2026, 10, 19, 9),
      );

      expect(total, 400);
    });
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

    test('a bucket starting at to is left out', () async {
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
          _point('hk', start, start.add(const Duration(hours: 1)), 80),
          _point(
            'hk',
            start.add(const Duration(hours: 1)),
            start.add(const Duration(hours: 2)),
            60,
          ),
        ],
      );
      final source = PluginHealthDataSource(health: health, ios: true);
      final to = DateTime.utc(2026, 10, 19, 9);

      expect(await source.stepHours(start, to), [_hour(19, 8, 80)]);
      expect(await source.stepTotal(start, to), 80);
    });

    test('stepTotal anchors the buckets at the exact from', () async {
      final from = DateTime.utc(2026, 10, 19, 8, 30);
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
          _point('hk', from, from.add(const Duration(hours: 1)), 80.4),
          _point(
            'hk',
            from.add(const Duration(hours: 1)),
            from.add(const Duration(hours: 2)),
            0.2,
          ),
          _point(
            'hk',
            from.add(const Duration(hours: 2)),
            from.add(const Duration(hours: 3)),
            20.6,
          ),
        ],
      );

      final total = await PluginHealthDataSource(
        health: health,
        ios: true,
      ).stepTotal(from, DateTime.utc(2026, 10, 19, 11, 30));

      expect(total, 101);
      verify(
        () => health.getHealthIntervalDataFromTypes(
          startDate: from,
          endDate: DateTime.utc(2026, 10, 19, 11, 30),
          types: [HealthDataType.STEPS],
          interval: 3600,
          recordingMethodsToFilter: [RecordingMethod.manual],
        ),
      ).called(1);
    });
  });

  group('requestNeeded', () {
    const channel = MethodChannel('stridequest/health');
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];

    void answer(Future<Object?> Function(MethodCall call) handler) {
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });
    }

    setUp(calls.clear);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    Future<bool?> ask({bool ios = true}) =>
        PluginHealthDataSource(health: health, ios: ios).requestNeeded();

    test('sends the HealthKit identifiers of the read types', () async {
      answer((_) async => 'shouldRequest');

      await ask();

      expect(calls.single.method, 'requestStatus');
      expect(calls.single.arguments, [
        'HKQuantityTypeIdentifierStepCount',
        'HKQuantityTypeIdentifierActiveEnergyBurned',
        'HKQuantityTypeIdentifierDistanceWalkingRunning',
        'HKCategoryTypeIdentifierSleepAnalysis',
      ]);
    });

    test('maps the native status', () async {
      answer((_) async => 'shouldRequest');
      expect(await ask(), isTrue);
      answer((_) async => 'unnecessary');
      expect(await ask(), isFalse);
      answer((_) async => 'unknown');
      expect(await ask(), isNull);
      answer((_) async => null);
      expect(await ask(), isNull);
    });

    test('a channel error is null', () async {
      answer((_) async => throw PlatformException(code: 'health_error'));

      expect(await ask(), isNull);
    });

    test('no native side is null', () async {
      expect(await ask(), isNull);
    });

    test('Android is null and never calls the channel', () async {
      answer((_) async => 'shouldRequest');

      expect(await ask(ios: false), isNull);
      expect(calls, isEmpty);
    });
  });
}

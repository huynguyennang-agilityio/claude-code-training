import 'dart:io';

import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/health_access.dart';

/// The platform side of health data: the `health` plugin, Health Connect's
/// availability and the system settings. It is the only place that touches the
/// plugin, so everything else is tested with a fake.
abstract interface class HealthDataSource {
  /// False when this phone cannot give health data (Health Connect missing).
  Future<bool> isAvailable();

  /// The metrics that may be read, or null when the platform will not say. Apple
  /// Health hides whether a read was refused, for privacy.
  Future<Set<HealthMetric>?> allowedMetrics();

  /// Shows the system permission dialog for every metric. True when it was
  /// shown without error; it does not say what the user chose.
  Future<bool> requestAuthorization();

  Future<void> installHealthConnect();

  Future<void> openSettings();

  /// The total of [metric] between [from] and [to]: kilocalories, metres or
  /// minutes asleep. Steps come from [stepHours] instead. 0 when there is no
  /// data. Throws on a read error.
  Future<int> total(HealthMetric metric, DateTime from, DateTime to);

  /// The steps of each UTC hour between [from] (floored to its hour) and [to],
  /// ordered, without manual entries and without double counting: an hour with
  /// steps only.
  Future<List<StepHour>> stepHours(DateTime from, DateTime to);

  /// The step records between [from] and [to], without the ones typed by hand.
  Future<List<StepRecord>> stepRecords(DateTime from, DateTime to);
}

/// [HealthDataSource] over the `health` plugin.
@LazySingleton(as: HealthDataSource)
class PluginHealthDataSource implements HealthDataSource {
  PluginHealthDataSource({
    @ignoreParam Health? health,
    @ignoreParam MethodChannel? settings,
    @ignoreParam bool? ios,
  }) : _health = health ?? Health(),
       _ios = ios ?? Platform.isIOS,
       _settings = settings ?? const MethodChannel(_settingsChannel);

  static const _settingsChannel = 'stridequest/settings';

  final Health _health;
  final MethodChannel _settings;
  final bool _ios;

  HealthDataType _type(HealthMetric metric) => switch (metric) {
    HealthMetric.steps => HealthDataType.STEPS,
    HealthMetric.calories => HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthMetric.distance =>
      _ios
          ? HealthDataType.DISTANCE_WALKING_RUNNING
          : HealthDataType.DISTANCE_DELTA,
    HealthMetric.sleep => HealthDataType.SLEEP_ASLEEP,
  };

  List<HealthDataType> get _types => [
    for (final metric in HealthMetric.values) _type(metric),
  ];

  @override
  Future<bool> isAvailable() => _health.isHealthConnectAvailable();

  @override
  Future<Set<HealthMetric>?> allowedMetrics() async {
    if (!Platform.isAndroid) return null;
    final allowed = <HealthMetric>{};
    for (final metric in HealthMetric.values) {
      if (await _health.hasPermissions([_type(metric)]) ?? false) {
        allowed.add(metric);
      }
    }
    return allowed;
  }

  @override
  Future<bool> requestAuthorization() async {
    try {
      return await _health.requestAuthorization(
        _types,
        permissions: [for (final _ in _types) HealthDataAccess.READ],
      );
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Future<void> openSettings() async {
    try {
      await _settings.invokeMethod<void>('open');
    } on PlatformException {
      // Nothing to open on this platform; the screen stays as it is.
    } on MissingPluginException {
      // Same, for a platform without the native side.
    }
  }

  @override
  Future<int> total(HealthMetric metric, DateTime from, DateTime to) async {
    final points = await _points(metric, from, to);
    if (metric == HealthMetric.sleep) {
      return points.fold<int>(
        0,
        (sum, point) => sum + point.dateTo.difference(point.dateFrom).inMinutes,
      );
    }
    final sum = points.fold<num>(0, (total, point) {
      final value = point.value;
      return total + (value is NumericHealthValue ? value.numericValue : 0);
    });
    return sum.round();
  }

  @override
  Future<List<StepHour>> stepHours(DateTime from, DateTime to) async {
    final start = _hourFloor(from);
    if (_ios) {
      // One statistics query with HealthKit's own merged total (sources by
      // priority), in hourly buckets anchored at the hour-aligned start. The
      // plugin's removeDuplicates compares dates too, so two hours with equal
      // values stay apart.
      final buckets = await _health.getHealthIntervalDataFromTypes(
        startDate: start,
        endDate: to,
        types: [HealthDataType.STEPS],
        interval: Duration.secondsPerHour,
        recordingMethodsToFilter: [RecordingMethod.manual],
      );
      final hours = <StepHour>[];
      for (final bucket in buckets) {
        final value = bucket.value;
        if (value is! NumericHealthValue) continue;
        final steps = value.numericValue.round();
        if (steps > 0) {
          hours.add(
            StepHour(hourStart: _hourFloor(bucket.dateFrom), steps: steps),
          );
        }
      }
      hours.sort((a, b) => a.hourStart.compareTo(b.hourStart));
      return hours;
    }
    final points = await _points(HealthMetric.steps, start, to, manual: false);
    return stepHoursFromSlices(
      [
        for (final point in points)
          if (point.value case NumericHealthValue(:final numericValue))
            (
              source: point.sourceId,
              from: point.dateFrom,
              to: point.dateTo,
              steps: numericValue.toDouble(),
            ),
      ],
      from: start,
      to: to,
    );
  }

  @override
  Future<List<StepRecord>> stepRecords(DateTime from, DateTime to) async {
    final points = await _points(HealthMetric.steps, from, to, manual: false);
    return [
      for (final point in points)
        if (point.value case NumericHealthValue(:final numericValue))
          if (numericValue.round() > 0)
            StepRecord(
              id: point.uuid,
              startTime: point.dateFrom,
              endTime: point.dateTo,
              steps: numericValue.round(),
            ),
    ];
  }

  Future<List<HealthDataPoint>> _points(
    HealthMetric metric,
    DateTime from,
    DateTime to, {
    bool manual = true,
  }) async {
    final type = _type(metric);
    final points = await _health.getHealthDataFromTypes(
      types: [type],
      startTime: from,
      endTime: to,
      recordingMethodsToFilter: manual ? const [] : [RecordingMethod.manual],
    );
    return _health.removeDuplicates(points);
  }
}

DateTime _hourFloor(DateTime moment) {
  final utc = moment.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
}

/// A step record reduced to what the hourly sum needs.
typedef StepSlice = ({String source, DateTime from, DateTime to, double steps});

/// Sums [slices] per UTC hour and source, then takes the largest source of each
/// hour, so two sources that saw the same walking count once. A record that
/// crosses an hour is split by time overlap; rounding happens once per hour.
/// Only hours in `[floor(from), to)` are kept, ordered, and those with steps.
List<StepHour> stepHoursFromSlices(
  Iterable<StepSlice> slices, {
  required DateTime from,
  required DateTime to,
}) {
  const hourMs = Duration.millisecondsPerHour;
  final first = _hourFloor(from).millisecondsSinceEpoch;
  final end = to.toUtc().millisecondsSinceEpoch;
  final sums = <int, Map<String, double>>{};

  void add(int hour, String source, double steps) {
    if (hour < first || hour >= end) return;
    final bySource = sums.putIfAbsent(hour, () => {});
    bySource[source] = (bySource[source] ?? 0) + steps;
  }

  for (final slice in slices) {
    final start = slice.from.toUtc().millisecondsSinceEpoch;
    final stop = slice.to.toUtc().millisecondsSinceEpoch;
    if (stop <= start) {
      add(start - start % hourMs, slice.source, slice.steps);
      continue;
    }
    final total = stop - start;
    for (var hour = start - start % hourMs; hour < stop; hour += hourMs) {
      final overlap =
          (stop < hour + hourMs ? stop : hour + hourMs) -
          (start > hour ? start : hour);
      add(hour, slice.source, slice.steps * overlap / total);
    }
  }

  final hours = <StepHour>[
    for (final MapEntry(key: hour, value: bySource) in sums.entries)
      if (bySource.values.reduce((a, b) => a > b ? a : b).round() > 0)
        StepHour(
          hourStart: DateTime.fromMillisecondsSinceEpoch(hour, isUtc: true),
          steps: bySource.values.reduce((a, b) => a > b ? a : b).round(),
        ),
  ];
  hours.sort((a, b) => a.hourStart.compareTo(b.hourStart));
  return hours;
}

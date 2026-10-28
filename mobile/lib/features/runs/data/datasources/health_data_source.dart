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

  /// The total of [metric] between [from] and [to]: steps, kilocalories, metres,
  /// or minutes asleep. 0 when there is no data. Throws on a read error.
  Future<int> total(HealthMetric metric, DateTime from, DateTime to);

  /// The step records between [from] and [to], without the ones typed by hand.
  Future<List<StepRecord>> stepRecords(DateTime from, DateTime to);
}

/// [HealthDataSource] over the `health` plugin.
@LazySingleton(as: HealthDataSource)
class PluginHealthDataSource implements HealthDataSource {
  PluginHealthDataSource({
    @ignoreParam Health? health,
    @ignoreParam MethodChannel? settings,
  }) : _health = health ?? Health(),
       _settings = settings ?? const MethodChannel(_settingsChannel);

  static const _settingsChannel = 'stridequest/settings';

  final Health _health;
  final MethodChannel _settings;

  HealthDataType _type(HealthMetric metric) => switch (metric) {
    HealthMetric.steps => HealthDataType.STEPS,
    HealthMetric.calories => HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthMetric.distance =>
      Platform.isIOS
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
    if (metric == HealthMetric.steps) {
      return await _health.getTotalStepsInInterval(from, to) ?? 0;
    }
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

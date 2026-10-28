import 'package:injectable/injectable.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/health_access.dart';
import '../../domain/failures/runs_failure.dart';
import '../../domain/repositories/health_repository.dart';
import '../datasources/health_data_source.dart';
import '../datasources/health_prompt_store.dart';

/// Works out [HealthAccessStatus] from what the platform says and from how often
/// the system dialog has been shown.
///
/// - **Android** says which metrics are allowed. Steps allowed: granted. Not
///   allowed: denied, and permanently denied once the dialog has been shown
///   twice, when Health Connect stops asking.
/// - **iOS** never says whether a read was refused. The dialog is shown once;
///   after it was shown the app can only treat access as granted, and a refused
///   read shows as 0 steps. Before it was shown the status is denied.
@LazySingleton(as: HealthRepository)
class HealthRepositoryImpl implements HealthRepository {
  HealthRepositoryImpl(
    this._source,
    this._prompts, {
    @ignoreParam DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  /// How many times Health Connect shows its dialog before it stops asking.
  static const androidDialogLimit = 2;

  final HealthDataSource _source;
  final HealthPromptStore _prompts;
  final DateTime Function() _clock;

  @override
  Future<HealthAccess> checkAccess() async {
    if (!await _source.isAvailable()) return const HealthAccess.unavailable();
    final asked = await _prompts.askedCount();
    final allowed = await _source.allowedMetrics();
    if (allowed == null) {
      // The platform will not say: the dialog having been shown is all we know.
      return asked > 0
          ? HealthAccess(
              HealthAccessStatus.granted,
              allowed: HealthMetric.values.toSet(),
            )
          : const HealthAccess.denied();
    }
    if (allowed.contains(HealthMetric.steps)) {
      return HealthAccess(HealthAccessStatus.granted, allowed: allowed);
    }
    return asked >= androidDialogLimit
        ? const HealthAccess.permanentlyDenied()
        : const HealthAccess.denied();
  }

  @override
  Future<HealthAccess> requestAccess() async {
    if (!await _source.isAvailable()) return const HealthAccess.unavailable();
    final shown = await _source.requestAuthorization();
    if (shown) await _prompts.recordAsked();
    final access = await checkAccess();
    // A dialog that could not be shown leaves the user where they were; on iOS
    // that would read as "asked once", so it must not count.
    return shown || access.isGranted ? access : const HealthAccess.denied();
  }

  @override
  Future<void> openSettings() => _source.openSettings();

  @override
  Future<void> installHealthConnect() => _source.installHealthConnect();

  @override
  Future<ActivityReading> readToday(Set<HealthMetric> allowed) async {
    final now = _clock();
    final midnight = _midnight(now);
    try {
      Future<int?> figure(HealthMetric metric) async {
        if (!allowed.contains(metric)) return null;
        // The night that ends today began yesterday evening.
        final from = metric == HealthMetric.sleep
            ? midnight.subtract(_sleepLead)
            : midnight;
        return _source.total(metric, from, now);
      }

      return ActivityReading(
        readAt: now,
        steps: await figure(HealthMetric.steps),
        calories: await figure(HealthMetric.calories),
        distanceM: await figure(HealthMetric.distance),
        sleepMinutes: await figure(HealthMetric.sleep),
      );
    } on Exception {
      throw const HealthFailure();
    }
  }

  @override
  Future<List<DailyFigures>> readDays(
    Set<HealthMetric> allowed, {
    required int days,
  }) async {
    final now = _clock();
    try {
      final figures = <DailyFigures>[];
      for (var back = days - 1; back >= 0; back--) {
        // A day is a calendar date: move on the date, not by 24-hour spans, so a
        // daylight-saving change cannot slip a day.
        final day = DateTime(now.year, now.month, now.day - back);
        final next = DateTime(day.year, day.month, day.day + 1);
        final end = next.isAfter(now) ? now : next;
        Future<int?> figure(HealthMetric metric) async {
          if (!allowed.contains(metric)) return null;
          final from = metric == HealthMetric.sleep
              ? day.subtract(_sleepLead)
              : day;
          return _source.total(metric, from, end);
        }

        figures.add(
          DailyFigures(
            date: day,
            steps: await figure(HealthMetric.steps),
            calories: await figure(HealthMetric.calories),
            distanceM: await figure(HealthMetric.distance),
            sleepMinutes: await figure(HealthMetric.sleep),
          ),
        );
      }
      return figures;
    } on Exception {
      throw const HealthFailure();
    }
  }

  @override
  Future<List<StepRecord>> readStepRecords({required DateTime from}) async {
    try {
      return await _source.stepRecords(from, _clock());
    } on Exception {
      throw const HealthFailure();
    }
  }

  /// A night is counted from 18:00 the evening before.
  static const _sleepLead = Duration(hours: 6);

  static DateTime _midnight(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);
}

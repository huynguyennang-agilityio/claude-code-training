import 'package:injectable/injectable.dart';

import '../entities/activity.dart';
import '../entities/health_access.dart';
import '../failures/runs_failure.dart';
import '../repositories/health_repository.dart';
import '../repositories/runs_repository.dart';

/// What a refresh found: today's figures, and whether they reached the backend.
class ActivitySync {
  const ActivitySync(this.reading, {this.failure});

  final ActivityReading reading;

  /// Null when everything was sent.
  final RunsFailure? failure;
}

/// The manual sync of the Active tab: reads today's figures and, when they can
/// be read, sends the steps that count toward challenges and the daily figures.
/// It spans the health data and the backend, so it is a use case.
///
/// A sync that fails to reach the backend still returns the reading, with the
/// [RunsFailure], so the screen keeps showing what was read.
@injectable
class SyncActivity {
  SyncActivity(this._health, this._runs);

  /// How many days of figures are sent: yesterday catches data that arrived late.
  static const daysSent = 2;

  /// The furthest back steps are read for a challenge joined long ago.
  static const maxStepWindow = Duration(days: 60);

  final HealthRepository _health;
  final RunsRepository _runs;

  /// Throws [HealthFailure] when the health data cannot be read.
  Future<ActivitySync> call(
    Set<HealthMetric> allowed, {
    DateTime Function() clock = DateTime.now,
  }) async {
    final reading = await _health.readToday(allowed);
    try {
      if (allowed.contains(HealthMetric.steps)) {
        final from = await _runs.earliestRunJoin();
        if (from != null) {
          final floor = clock().subtract(maxStepWindow);
          final records = await _health.readStepRecords(
            from: from.isBefore(floor) ? floor : from,
          );
          if (records.isNotEmpty) await _runs.syncSteps(records);
        }
      }
      final days = await _health.readDays(allowed, days: daysSent);
      await _runs.saveDailyActivity(days);
      return ActivitySync(reading);
    } on RunsFailure catch (failure) {
      return ActivitySync(reading, failure: failure);
    }
  }
}

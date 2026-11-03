import 'package:injectable/injectable.dart';

import '../entities/activity.dart';
import '../entities/health_access.dart';
import '../failures/runs_failure.dart';
import '../repositories/health_repository.dart';
import '../repositories/runs_repository.dart';
import '../repositories/sync_state_repository.dart';

/// What a refresh found: today's figures, and whether they reached the backend.
class ActivitySync {
  const ActivitySync(this.reading, {this.failure});

  final ActivityReading reading;

  /// Null when everything was sent.
  final RunsFailure? failure;
}

/// The sync of the Active tab: reads today's figures and, when they can be read,
/// sends the steps of each hour that count toward challenges and the daily
/// figures. It spans the health data, the backend and the sync state, so it is
/// a use case.
///
/// The window starts 48 hours before the watermark (the end of the last fully
/// successful sync), never earlier than 30 days back: an app left closed for
/// days catches up, and data that arrived late is sent again. With no watermark
/// the window is 30 days. The watermark moves to the sync's time only when steps are
/// allowed and every request succeeded, so turning steps on later still
/// catches up.
///
/// A sync that fails to reach the backend still returns the reading, with the
/// [RunsFailure], so the screen keeps showing what was read.
@injectable
class SyncActivity {
  SyncActivity(this._health, this._runs, this._state);

  /// The furthest back a sync reads.
  static const maxWindow = Duration(days: 30);

  /// How far before the watermark a sync reads again.
  static const overlap = Duration(hours: 48);

  final HealthRepository _health;
  final RunsRepository _runs;
  final SyncStateRepository _state;

  /// Throws [HealthFailure] when the health data cannot be read.
  Future<ActivitySync> call(
    Set<HealthMetric> allowed, {
    DateTime Function() clock = DateTime.now,
  }) async {
    final reading = await _health.readToday(allowed);
    try {
      final now = clock();
      final state = await _state.load(now);
      final windowStart = _windowStart(now, state.watermark);
      final steps = allowed.contains(HealthMetric.steps);
      if (steps) await _sendStepHours(windowStart, now);
      await _sendDays(allowed, windowStart, state.firstSyncAt, now);
      // Without steps allowed the hours were not sent, so the window must stay
      // open for the sync that follows turning steps on.
      if (steps) await state.saveWatermark(now);
      return ActivitySync(reading);
    } on RunsFailure catch (failure) {
      return ActivitySync(reading, failure: failure);
    }
  }

  DateTime _windowStart(DateTime now, DateTime? watermark) {
    final floor = now.subtract(maxWindow);
    if (watermark == null) return floor;
    final start = watermark.subtract(overlap);
    return start.isBefore(floor) ? floor : start;
  }

  /// Sends the hours from [windowStart], but not before the earliest join:
  /// steps before it can never count. Nothing is sent with no active run.
  Future<void> _sendStepHours(DateTime windowStart, DateTime now) async {
    final joined = await _runs.earliestRunJoin();
    if (joined == null) return;
    final hours = await _health.readStepHours(
      from: joined.isAfter(windowStart) ? joined : windowStart,
      to: now,
    );
    if (hours.isNotEmpty) await _runs.syncStepHours(hours);
  }

  /// Sends every calendar day from [windowStart] (the join does not matter: the
  /// figures do not count toward challenges), but not before the day of
  /// [firstSyncAt], through today.
  Future<void> _sendDays(
    Set<HealthMetric> allowed,
    DateTime windowStart,
    DateTime firstSyncAt,
    DateTime now,
  ) async {
    final from = firstSyncAt.isAfter(windowStart) ? firstSyncAt : windowStart;
    final count = _dayOf(now).difference(_dayOf(from)).inDays + 1;
    final days = await _health.readDays(allowed, days: count < 1 ? 1 : count);
    await _runs.saveDailyActivity(days);
  }

  /// The calendar day of [time] as a UTC date, so that a day is always 24 hours.
  DateTime _dayOf(DateTime time) =>
      DateTime.utc(time.year, time.month, time.day);
}

import '../entities/activity.dart';

/// What the backend knows about the caller's challenges and health figures
/// (`docs/api/runs.md`). Every method throws `RunsFailure` on error.
abstract interface class RunsRepository {
  /// Counts the step records toward the caller's active run challenges. Sent in
  /// requests of at most 500.
  Future<StepSyncResult> syncSteps(List<StepRecord> records);

  /// Counts the steps of each UTC hour toward the caller's active run
  /// challenges (`PUT /runs/step-hours`; an hour sent again replaces the stored
  /// one). Sent in requests of at most 744 hours, and no request for an empty
  /// list.
  Future<StepSyncResult> syncStepHours(List<StepHour> hours);

  /// Stores the figures of the days; a day replaces the one stored. Sent in
  /// requests of at most 7 days, and no request for an empty list.
  Future<void> saveDailyActivity(List<DailyFigures> days);

  /// The challenges the caller is in (active or paused), with progress.
  Future<MyChallengePage> myChallenges({String? cursor, int limit});

  /// When the earliest active run challenge was joined, or null when there is
  /// none: steps before that time can never count.
  Future<DateTime?> earliestRunJoin();

  /// When steps began to count for the active run challenge that has counted
  /// longest: the later of its join and its start, which may still be ahead.
  /// Null when there is none.
  Future<DateTime?> earliestRunCounting();
}

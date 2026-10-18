import '../entities/activity.dart';

/// What the backend knows about the caller's challenges and health figures
/// (`docs/api/runs.md`). Every method throws `RunsFailure` on error.
abstract interface class RunsRepository {
  /// Counts the step records toward the caller's active run challenges. Sent in
  /// requests of at most 500.
  Future<StepSyncResult> syncSteps(List<StepRecord> records);

  /// Stores the figures of up to 7 days; a day replaces the one stored.
  Future<void> saveDailyActivity(List<DailyFigures> days);

  /// The challenges the caller is in (active or paused), with progress.
  Future<MyChallengePage> myChallenges({String? cursor, int limit});

  /// When the earliest active run challenge was joined, or null when there is
  /// none: steps before that time can never count.
  Future<DateTime?> earliestRunJoin();
}

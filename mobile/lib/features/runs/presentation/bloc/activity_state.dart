part of 'activity_bloc.dart';

class ActivityState extends Equatable {
  const ActivityState({
    this.allowed = const {},
    this.reading,
    this.busy = false,
    this.error,
    this.syncedAt,
  });

  /// The metrics the user allowed; the others show "Not allowed".
  final Set<HealthMetric> allowed;

  /// Today's figures; null until the first read.
  final ActivityReading? reading;

  /// Reading and syncing.
  final bool busy;

  /// What went wrong in the last refresh, or null.
  final String? error;

  /// When the figures last reached StrideQuest.
  final DateTime? syncedAt;

  /// The first read is running and there is nothing to show yet.
  bool get isLoading => busy && reading == null;

  ActivityState copyWith({
    Set<HealthMetric>? allowed,
    ActivityReading? reading,
    bool? busy,
    String? error,
    bool clearError = false,
    DateTime? syncedAt,
  }) => ActivityState(
    allowed: allowed ?? this.allowed,
    reading: reading ?? this.reading,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
    syncedAt: syncedAt ?? this.syncedAt,
  );

  @override
  List<Object?> get props => [allowed, reading, busy, error, syncedAt];
}

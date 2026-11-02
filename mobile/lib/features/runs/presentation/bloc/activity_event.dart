part of 'activity_bloc.dart';

sealed class ActivityEvent extends Equatable {
  const ActivityEvent();

  @override
  List<Object?> get props => [];
}

/// The tab opened with access to [allowed] metrics: read and sync.
class ActivityStarted extends ActivityEvent {
  const ActivityStarted(this.allowed);

  final Set<HealthMetric> allowed;

  @override
  List<Object?> get props => [allowed];
}

/// The user tapped **Refresh data**.
class ActivityRefreshRequested extends ActivityEvent {
  const ActivityRefreshRequested();
}

/// The [HealthSync] has a new state.
class _SyncStateChanged extends ActivityEvent {
  const _SyncStateChanged(this.sync);

  final HealthSyncState sync;

  @override
  List<Object?> get props => [sync];
}

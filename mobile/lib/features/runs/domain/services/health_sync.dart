import 'package:equatable/equatable.dart';

import '../entities/activity.dart';

/// What the screens show of the health sync.
class HealthSyncState extends Equatable {
  const HealthSyncState({
    this.busy = false,
    this.reading,
    this.error,
    this.syncedAt,
  });

  /// A sync is running.
  final bool busy;

  /// Today's figures from the last sync that read them; null before the first.
  final ActivityReading? reading;

  /// What went wrong in the last sync, or null.
  final String? error;

  /// When the figures last reached StrideQuest.
  final DateTime? syncedAt;

  @override
  List<Object?> get props => [busy, reading, error, syncedAt];
}

/// The app-wide health sync: it runs when the app opens, resumes or a session
/// starts, and on demand. Screens read [state] and [stream] and ask for a
/// [sync]; they never run the sync themselves.
abstract interface class HealthSync {
  /// The latest state.
  HealthSyncState get state;

  /// Every change of [state].
  Stream<HealthSyncState> get stream;

  /// Starts listening for triggers and runs the cold-start sync. The app entry
  /// point calls it once, after the dependencies are set up.
  void start();

  /// Runs a sync if signed in and steps are allowed; joins one that is running.
  /// [force] skips the throttle (the **Refresh data** button). Never throws.
  Future<void> sync({bool force = false});

  /// Stops listening; the container calls it on reset.
  Future<void> dispose();
}

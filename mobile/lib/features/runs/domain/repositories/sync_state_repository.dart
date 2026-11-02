/// What the app remembers, per signed-in user and per device, about its health
/// syncs ([plan 030](../../../../../docs/plans/030-health-sync-single-session.md),
/// assumptions 4 and 5). With no signed-in user nothing is stored.
abstract interface class SyncStateRepository {
  /// Reads the state of one sync. The user is resolved once, here: the returned
  /// [SyncState] keeps writing under that user even if the session changes
  /// before the sync ends. The first call for a user stores [now] as its
  /// [SyncState.firstSyncAt].
  Future<SyncState> load(DateTime now);
}

/// The sync state of one user, as read at the start of one sync.
abstract interface class SyncState {
  /// The time (end) of the last fully successful sync with steps allowed, or
  /// null if there was none.
  DateTime? get watermark;

  /// When the first sync attempt ran for this user on this device. It is
  /// recorded even if that sync fails.
  DateTime get firstSyncAt;

  /// Stores [at] as the watermark of the user this state was loaded for. Does
  /// nothing when there was no signed-in user.
  Future<void> saveWatermark(DateTime at);
}

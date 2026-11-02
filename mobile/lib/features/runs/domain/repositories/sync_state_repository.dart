/// What the app remembers, per signed-in user and per device, about its health
/// syncs ([plan 030](../../../../../docs/plans/030-health-sync-single-session.md),
/// assumptions 4 and 5). With no signed-in user nothing is stored.
abstract interface class SyncStateRepository {
  /// When the last fully successful sync started reading, or null if none.
  Future<DateTime?> watermark();

  Future<void> saveWatermark(DateTime at);

  /// When a sync first ran for this user on this device. The first call stores
  /// [now] and returns it; later calls return the stored time.
  Future<DateTime> firstSyncAt(DateTime now);
}

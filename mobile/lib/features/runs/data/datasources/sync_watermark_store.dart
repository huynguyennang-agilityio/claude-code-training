import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Remembers, for each user id, the sync watermark and the time of their first
/// sync on this device.
abstract interface class SyncWatermarkStore {
  Future<DateTime?> watermark(String userId);

  Future<void> saveWatermark(String userId, DateTime at);

  Future<DateTime?> firstSyncAt(String userId);

  Future<void> saveFirstSyncAt(String userId, DateTime at);
}

/// A [SyncWatermarkStore] kept in the device's secure storage, one key per user
/// so that an account never reads another account's times.
@LazySingleton(as: SyncWatermarkStore)
class SecureSyncWatermarkStore implements SyncWatermarkStore {
  SecureSyncWatermarkStore(this._storage);

  final FlutterSecureStorage _storage;

  static String watermarkKey(String userId) => 'sync.watermark.$userId';

  static String firstSyncKey(String userId) => 'sync.first_sync_at.$userId';

  @override
  Future<DateTime?> watermark(String userId) => _read(watermarkKey(userId));

  @override
  Future<void> saveWatermark(String userId, DateTime at) =>
      _write(watermarkKey(userId), at);

  @override
  Future<DateTime?> firstSyncAt(String userId) => _read(firstSyncKey(userId));

  @override
  Future<void> saveFirstSyncAt(String userId, DateTime at) =>
      _write(firstSyncKey(userId), at);

  Future<DateTime?> _read(String key) async {
    try {
      final raw = await _storage.read(key: key);
      return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    } on Exception {
      return null;
    }
  }

  Future<void> _write(String key, DateTime at) async {
    try {
      await _storage.write(key: key, value: at.toUtc().toIso8601String());
    } on Exception {
      // Without storage the next sync reads the full window again, which is
      // safe: the backend upserts hours and replaces days.
    }
  }
}

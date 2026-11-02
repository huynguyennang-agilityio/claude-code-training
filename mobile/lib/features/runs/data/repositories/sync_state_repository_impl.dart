import 'package:injectable/injectable.dart';

import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../domain/repositories/sync_state_repository.dart';
import '../datasources/sync_watermark_store.dart';

/// [SyncStateRepository] for the user of the stored session.
@LazySingleton(as: SyncStateRepository)
class SyncStateRepositoryImpl implements SyncStateRepository {
  SyncStateRepositoryImpl(this._session, this._store);

  final AuthLocalDataSource _session;
  final SyncWatermarkStore _store;

  @override
  Future<SyncState> load(DateTime now) async {
    final id = (await _session.readSession())?.user.id;
    if (id == null) return _UserSyncState(_store, null, null, now);
    final stored = await _store.firstSyncAt(id);
    if (stored == null) await _store.saveFirstSyncAt(id, now);
    return _UserSyncState(
      _store,
      id,
      await _store.watermark(id),
      stored ?? now,
    );
  }
}

/// The state of the user [_userId], fixed when it was loaded.
class _UserSyncState implements SyncState {
  _UserSyncState(this._store, this._userId, this.watermark, this.firstSyncAt);

  final SyncWatermarkStore _store;
  final String? _userId;

  @override
  final DateTime? watermark;

  @override
  final DateTime firstSyncAt;

  @override
  Future<void> saveWatermark(DateTime at) async {
    final id = _userId;
    if (id != null) await _store.saveWatermark(id, at);
  }
}

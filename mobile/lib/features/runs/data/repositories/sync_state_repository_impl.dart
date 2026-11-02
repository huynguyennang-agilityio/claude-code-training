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

  Future<String?> _userId() async => (await _session.readSession())?.user.id;

  @override
  Future<DateTime?> watermark() async {
    final id = await _userId();
    return id == null ? null : _store.watermark(id);
  }

  @override
  Future<void> saveWatermark(DateTime at) async {
    final id = await _userId();
    if (id != null) await _store.saveWatermark(id, at);
  }

  @override
  Future<DateTime> firstSyncAt(DateTime now) async {
    final id = await _userId();
    if (id == null) return now;
    final stored = await _store.firstSyncAt(id);
    if (stored != null) return stored;
    await _store.saveFirstSyncAt(id, now);
    return now;
  }
}

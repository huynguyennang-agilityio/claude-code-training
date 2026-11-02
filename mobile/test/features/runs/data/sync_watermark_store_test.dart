import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:stridequest/features/auth/data/models/auth_session_model.dart';
import 'package:stridequest/features/runs/data/datasources/sync_watermark_store.dart';
import 'package:stridequest/features/runs/data/repositories/sync_state_repository_impl.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

class _MockSession extends Mock implements AuthLocalDataSource {}

AuthSessionModel _session(String id) => AuthSessionModel.fromJson({
  'user': {
    'id': id,
    'email': 'a@b.c',
    'display_name': 'A',
    'created_at': '2026-10-01T00:00:00Z',
  },
  'tokens': {
    'access_token': 'a',
    'refresh_token': 'r',
    'token_type': 'bearer',
    'expires_in': 900,
  },
});

void main() {
  late _MockStorage storage;
  late SecureSyncWatermarkStore store;
  final values = <String, String>{};

  setUp(() {
    values.clear();
    storage = _MockStorage();
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((i) async {
      values[i.namedArguments[#key] as String] =
          i.namedArguments[#value] as String;
    });
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((i) async => values[i.namedArguments[#key] as String]);
    store = SecureSyncWatermarkStore(storage);
  });

  group('SecureSyncWatermarkStore', () {
    test('nothing stored reads as null', () async {
      expect(await store.watermark('u1'), isNull);
      expect(await store.firstSyncAt('u1'), isNull);
    });

    test('times round-trip as UTC strings under a key per user', () async {
      final at = DateTime.utc(2026, 11, 2, 9, 30);

      await store.saveWatermark('u1', at);
      await store.saveFirstSyncAt('u1', at);

      expect(values['sync.watermark.u1'], '2026-11-02T09:30:00.000Z');
      expect(values['sync.first_sync_at.u1'], '2026-11-02T09:30:00.000Z');
      expect((await store.watermark('u1'))?.toUtc(), at);
      expect((await store.firstSyncAt('u1'))?.toUtc(), at);
    });

    test('another user does not see the times', () async {
      await store.saveWatermark('u1', DateTime.utc(2026, 11, 2));

      expect(await store.watermark('u2'), isNull);
    });

    test('an unreadable or failing storage is treated as empty', () async {
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenThrow(PlatformException(code: 'boom'));
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(PlatformException(code: 'boom'));

      expect(await store.watermark('u1'), isNull);
      await store.saveWatermark('u1', DateTime.utc(2026));
    });
  });

  group('SyncStateRepositoryImpl', () {
    late _MockSession session;
    late SyncStateRepositoryImpl repository;
    final t0 = DateTime.utc(2026, 11, 2, 8);

    setUp(() {
      session = _MockSession();
      when(session.readSession).thenAnswer((_) async => _session('u1'));
      repository = SyncStateRepositoryImpl(session, store);
    });

    test('keeps the watermark of the signed-in user', () async {
      await repository.saveWatermark(t0);

      expect(values.keys, ['sync.watermark.u1']);
      expect((await repository.watermark())?.toUtc(), t0);
    });

    test('stores the first sync once and returns it afterwards', () async {
      expect((await repository.firstSyncAt(t0)).toUtc(), t0);
      expect(
        (await repository.firstSyncAt(t0.add(const Duration(days: 1)))).toUtc(),
        t0,
      );
    });

    test('with no signed-in user nothing is stored', () async {
      when(session.readSession).thenAnswer((_) async => null);

      await repository.saveWatermark(t0);

      expect(await repository.watermark(), isNull);
      expect(await repository.firstSyncAt(t0), t0);
      expect(values, isEmpty);
    });
  });
}

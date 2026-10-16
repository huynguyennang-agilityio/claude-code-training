import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/data/datasources/auth_local_data_source.dart';

import '../../../../helpers/auth_fixtures.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late SecureAuthLocalDataSource local;
  final stored = <String, String>{};

  setUp(() {
    stored.clear();
    storage = _MockStorage();
    local = SecureAuthLocalDataSource(storage);
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((call) async => stored[call.namedArguments[#key] as String]);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((call) async {
      stored[call.namedArguments[#key] as String] =
          call.namedArguments[#value] as String;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer(
      (call) async => stored.remove(call.namedArguments[#key] as String),
    );
  });

  test('saves the session as JSON and reads it back', () async {
    await local.saveSession(testSession());

    expect(await local.readSession(), testSession());
    expect(
      jsonDecode(stored[SecureAuthLocalDataSource.sessionKey]!),
      containsPair('tokens', containsPair('expires_in', 900)),
    );
  });

  test('returns null when nothing is stored', () async {
    expect(await local.readSession(), isNull);
  });

  test('clear removes the session', () async {
    await local.saveSession(testSession());
    await local.clear();

    expect(await local.readSession(), isNull);
  });

  test('drops a corrupt entry and reads it as signed out', () async {
    stored[SecureAuthLocalDataSource.sessionKey] = '{"user": 1}';

    expect(await local.readSession(), isNull);
    expect(stored, isEmpty);
  });
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../models/auth_session_model.dart';

/// Where the signed-in session (user and tokens) is kept on the device.
abstract interface class AuthLocalDataSource {
  Future<AuthSessionModel?> readSession();

  Future<void> saveSession(AuthSessionModel session);

  Future<void> clear();
}

/// [AuthLocalDataSource] in the Keychain (iOS) or Keystore (Android), as the
/// contract requires: tokens never go to plain preferences.
@LazySingleton(as: AuthLocalDataSource)
class SecureAuthLocalDataSource implements AuthLocalDataSource {
  SecureAuthLocalDataSource(this._storage);

  static const sessionKey = 'auth.session';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSessionModel?> readSession() async {
    final stored = await _storage.read(key: sessionKey);
    if (stored == null) return null;
    try {
      return AuthSessionModel.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
    } on Object {
      // A corrupt or outdated entry: treat it as signed out and drop it.
      await clear();
      return null;
    }
  }

  @override
  Future<void> saveSession(AuthSessionModel session) {
    return _storage.write(key: sessionKey, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: sessionKey);
}

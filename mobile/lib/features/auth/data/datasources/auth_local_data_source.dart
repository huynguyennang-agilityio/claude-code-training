import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../models/auth_session_model.dart';

/// Where the signed-in session (user and tokens) is kept on the device.
abstract interface class AuthLocalDataSource {
  /// The stored session, or null when there is none or it cannot be read.
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
    final String? stored;
    try {
      stored = await _storage.read(key: sessionKey);
    } on PlatformException {
      // The Keystore entry can become unreadable, for example after a backup
      // restore to a new device. Start signed out instead of failing.
      await _clearQuietly();
      return null;
    }
    if (stored == null) return null;
    try {
      return AuthSessionModel.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
      // Corrupt JSON, a wrong token_type or a missing field.
    } on FormatException {
      await _clearQuietly();
      return null;
    } on TypeError {
      await _clearQuietly();
      return null;
    }
  }

  @override
  Future<void> saveSession(AuthSessionModel session) {
    return _storage.write(key: sessionKey, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: sessionKey);

  Future<void> _clearQuietly() async {
    try {
      await clear();
    } on PlatformException {
      // Nothing more to do: the entry is unreadable either way.
    }
  }
}

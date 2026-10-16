import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../../core/network/auth_token_handler.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

/// The auth session: signs in and out through [AuthRemoteDataSource] and
/// keeps the tokens in [AuthLocalDataSource].
///
/// It is also the [AuthTokenHandler] the network layer uses to attach and
/// refresh tokens, so the session has a single owner. `auth_module.dart`
/// registers it under both interfaces.
@lazySingleton
class AuthRepositoryImpl implements AuthRepository, AuthTokenHandler {
  AuthRepositoryImpl(this._remote, this._local);

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final _sessionExpired = StreamController<void>.broadcast();

  @override
  Stream<void> get sessionExpired => _sessionExpired.stream;

  @override
  Future<AuthUser?> restoreSession() async {
    final session = await _local.readSession();
    return session?.user.toEntity();
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final session = await _remote.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _local.saveSession(session);
    return session.user.toEntity();
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final session = await _remote.signIn(email: email, password: password);
    await _local.saveSession(session);
    return session.user.toEntity();
  }

  @override
  Future<void> signOut() async {
    final session = await _local.readSession();
    await _local.clear();
    if (session == null) return;
    try {
      await _remote.signOut(session.tokens.refreshToken);
    } on AuthFailure {
      // The user is signed out on this device either way. A token the backend
      // could not revoke expires on its own (30 days).
    }
  }

  @override
  Future<String?> accessToken() async {
    final session = await _local.readSession();
    return session?.tokens.accessToken;
  }

  @override
  Future<bool> refreshTokens() async {
    final session = await _local.readSession();
    if (session == null) return false;
    try {
      final tokens = await _remote.refresh(session.tokens.refreshToken);
      await _local.saveSession(session.copyWith(tokens: tokens));
      return true;
    } on AuthFailure {
      return false;
    }
  }

  @override
  Future<void> expireSession() async {
    await _local.clear();
    _sessionExpired.add(null);
  }

  @disposeMethod
  Future<void> dispose() => _sessionExpired.close();
}

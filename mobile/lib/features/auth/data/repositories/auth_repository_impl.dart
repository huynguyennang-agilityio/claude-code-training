import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../../../core/network/auth_token_handler.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_session_model.dart';

/// The auth session: signs in and out through [AuthRemoteDataSource] and
/// keeps the tokens in [AuthLocalDataSource].
///
/// It is also the [AuthTokenHandler] the network layer uses to attach and
/// refresh tokens, so the session has a single owner. `auth_module.dart`
/// registers it under both interfaces.
///
/// Every change to the stored session runs one at a time, so a refresh that
/// is still in flight can never write tokens back after a sign-out.
@lazySingleton
class AuthRepositoryImpl implements AuthRepository, AuthTokenHandler {
  AuthRepositoryImpl(this._remote, this._local);

  /// Refresh failures that mean the refresh token itself is no good.
  static const _rejectedRefreshCodes = {
    AuthFailureCode.invalidRefreshToken,
    AuthFailureCode.validation,
  };

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final _sessionStarted = StreamController<AuthUser>.broadcast();
  final _sessionExpired = StreamController<void>.broadcast();
  final _userUpdated = StreamController<AuthUser>.broadcast();
  Future<void> _lastChange = Future.value();

  @override
  Stream<AuthUser> get sessionStarted => _sessionStarted.stream;

  @override
  Stream<AuthUser> get userUpdated => _userUpdated.stream;

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
  }) {
    return _serialized(() async {
      final session = await _remote.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      return _startSession(session);
    });
  }

  @override
  Future<AuthUser> signIn({required String email, required String password}) {
    return _serialized(() async {
      final session = await _remote.signIn(email: email, password: password);
      return _startSession(session);
    });
  }

  @override
  Future<AuthUser> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    // Outside `_serialized`: a 401 here makes the auth interceptor call
    // `refreshTokens`, which waits for the queue; holding it would deadlock.
    final user = await _remote.changeEmail(
      newEmail: newEmail,
      currentPassword: currentPassword,
    );
    return _serialized(() async {
      final session = await _local.readSession();
      // A sign-out, or another user's session, while the request ran leaves
      // nothing to update.
      if (session == null || session.user.id != user.id) {
        return user.toEntity();
      }
      await _local.saveSession(session.copyWith(user: user));
      final entity = user.toEntity();
      _userUpdated.add(entity);
      return entity;
    });
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final before = await _local.readSession();
    // Outside `_serialized`, for the same reason as `changeEmail`.
    final tokens = await _remote.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    // The old refresh token is revoked now, so the new pair must be stored
    // before this returns.
    return _serialized(() async {
      final session = await _local.readSession();
      // A sign-out, or another user's session, while the request ran leaves
      // nothing to update.
      if (before == null ||
          session == null ||
          session.user.id != before.user.id) {
        return;
      }
      await _local.saveSession(session.copyWith(tokens: tokens));
    });
  }

  @override
  Future<void> signOut() {
    return _serialized(() async {
      final session = await _local.readSession();
      await _local.clear();
      if (session == null) return;
      try {
        await _remote.signOut(session.tokens.refreshToken);
      } on AuthFailure {
        // The user is signed out on this device either way. A token the
        // backend could not revoke expires on its own (30 days).
      }
    });
  }

  @override
  Future<String?> accessToken() async {
    final session = await _local.readSession();
    return session?.tokens.accessToken;
  }

  @override
  Future<TokenRefreshResult> refreshTokens() {
    return _serialized(() async {
      final session = await _local.readSession();
      if (session == null) return TokenRefreshResult.notRefreshed;
      try {
        final tokens = await _remote.refresh(session.tokens.refreshToken);
        await _local.saveSession(session.copyWith(tokens: tokens));
        return TokenRefreshResult.refreshed;
      } on AuthFailure catch (failure) {
        return _rejectedRefreshCodes.contains(failure.code)
            ? TokenRefreshResult.rejected
            : TokenRefreshResult.notRefreshed;
      }
    });
  }

  @override
  Future<void> expireSession() {
    return _serialized(() async {
      await _local.clear();
      _sessionExpired.add(null);
    });
  }

  /// Stores [session] and announces its user on [sessionStarted].
  Future<AuthUser> _startSession(AuthSessionModel session) async {
    await _local.saveSession(session);
    final user = session.user.toEntity();
    _sessionStarted.add(user);
    return user;
  }

  /// Runs [change] after every earlier session change has finished.
  Future<T> _serialized<T>(Future<T> Function() change) {
    final result = _lastChange.then((_) => change());
    _lastChange = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @disposeMethod
  Future<void> dispose() async {
    await _sessionStarted.close();
    await _sessionExpired.close();
    await _userUpdated.close();
  }
}

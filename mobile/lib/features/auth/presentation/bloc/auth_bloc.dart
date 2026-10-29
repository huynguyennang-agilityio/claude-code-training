import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// The app-wide auth **session**: whether someone is signed in. The router
/// listens to it to redirect.
///
/// It only owns the session. Each form has its own bloc (`SignInBloc`,
/// `SignUpBloc`, and one per future flow, such as forgot password); they send
/// their results to the repository, and this bloc learns of a new session from
/// the repository's `sessionStarted` and `userUpdated` streams.
///
/// Unlike those blocs, which are factories scoped to a route, this one is a
/// lazy singleton: the router and every screen need the same instance.
@lazySingleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthUnknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<_AuthSessionStarted>(_onSessionStarted);
    on<_AuthSessionExpired>(_onSessionExpired);
    on<_AuthUserUpdated>(_onUserUpdated);
    on<_AuthAccountDeleted>(_onAccountDeleted);
    _sessionStarted = _repository.sessionStarted.listen(
      (user) => add(_AuthSessionStarted(user)),
    );
    _userUpdated = _repository.userUpdated.listen(
      (user) => add(_AuthUserUpdated(user)),
    );
    _sessionExpired = _repository.sessionExpired.listen(
      (_) => add(const _AuthSessionExpired()),
    );
    _accountDeleted = _repository.accountDeleted.listen(
      (_) => add(const _AuthAccountDeleted()),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthUser> _sessionStarted;
  late final StreamSubscription<AuthUser> _userUpdated;
  late final StreamSubscription<void> _sessionExpired;
  late final StreamSubscription<void> _accountDeleted;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final user = await _repository.restoreSession();
    emit(user == null ? const AuthUnauthenticated() : AuthAuthenticated(user));
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.signOut();
    emit(const AuthUnauthenticated());
  }

  void _onSessionStarted(_AuthSessionStarted event, Emitter<AuthState> emit) {
    emit(AuthAuthenticated(event.user));
  }

  /// Replaces the signed-in user (a new email). Ignored when signed out, so a
  /// late announcement cannot sign anyone back in.
  void _onUserUpdated(_AuthUserUpdated event, Emitter<AuthState> emit) {
    if (state is AuthAuthenticated) emit(AuthAuthenticated(event.user));
  }

  void _onSessionExpired(_AuthSessionExpired event, Emitter<AuthState> emit) {
    emit(const AuthUnauthenticated(sessionExpired: true));
  }

  void _onAccountDeleted(_AuthAccountDeleted event, Emitter<AuthState> emit) {
    emit(const AuthUnauthenticated(accountDeleted: true));
  }

  @override
  Future<void> close() async {
    await _sessionStarted.cancel();
    await _userUpdated.cancel();
    await _sessionExpired.cancel();
    await _accountDeleted.cancel();
    return super.close();
  }
}

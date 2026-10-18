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
/// the repository's `sessionStarted` stream.
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
    _sessionStarted = _repository.sessionStarted.listen(
      (user) => add(_AuthSessionStarted(user)),
    );
    _sessionExpired = _repository.sessionExpired.listen(
      (_) => add(const _AuthSessionExpired()),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthUser> _sessionStarted;
  late final StreamSubscription<void> _sessionExpired;

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

  void _onSessionExpired(_AuthSessionExpired event, Emitter<AuthState> emit) {
    emit(const AuthUnauthenticated(sessionExpired: true));
  }

  @override
  Future<void> close() async {
    await _sessionStarted.cancel();
    await _sessionExpired.cancel();
    return super.close();
  }
}

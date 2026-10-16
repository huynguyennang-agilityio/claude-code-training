import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// App-wide auth state. The router listens to it to redirect.
///
/// Unlike feature blocs, which are factories scoped to a route, this one is a
/// lazy singleton: the router and every screen need the same instance.
@lazySingleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthUnknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<_AuthSessionExpired>(_onSessionExpired);
    _sessionExpired = _repository.sessionExpired.listen(
      (_) => add(const _AuthSessionExpired()),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _sessionExpired;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final user = await _repository.restoreSession();
    emit(user == null ? const AuthUnauthenticated() : AuthAuthenticated(user));
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) {
    return _authenticate(
      emit,
      () => _repository.signIn(email: event.email, password: event.password),
    );
  }

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) {
    return _authenticate(
      emit,
      () => _repository.signUp(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      ),
    );
  }

  Future<void> _authenticate(
    Emitter<AuthState> emit,
    Future<AuthUser> Function() request,
  ) async {
    emit(const AuthInProgress());
    try {
      emit(AuthAuthenticated(await request()));
    } on AuthFailure catch (failure) {
      emit(AuthUnauthenticated(failure: failure));
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.signOut();
    emit(const AuthUnauthenticated());
  }

  void _onSessionExpired(_AuthSessionExpired event, Emitter<AuthState> emit) {
    emit(const AuthUnauthenticated(sessionExpired: true));
  }

  @override
  Future<void> close() async {
    await _sessionExpired.cancel();
    return super.close();
  }
}

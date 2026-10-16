part of 'auth_bloc.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Before the stored session has been checked.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// A sign in or sign up request is running.
final class AuthInProgress extends AuthState {
  const AuthInProgress();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.failure, this.sessionExpired = false});

  /// Why the last sign in or sign up failed, if it did.
  final AuthFailure? failure;

  /// True when the session ended without the user signing out.
  final bool sessionExpired;

  @override
  List<Object?> get props => [failure?.code, sessionExpired];
}

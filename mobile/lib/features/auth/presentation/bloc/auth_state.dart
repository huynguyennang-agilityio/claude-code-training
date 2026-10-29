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

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({
    this.sessionExpired = false,
    this.accountDeleted = false,
  });

  /// True when the session ended without the user signing out.
  final bool sessionExpired;

  /// True when the user deleted their account on this device.
  final bool accountDeleted;

  @override
  List<Object?> get props => [sessionExpired, accountDeleted];
}

part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// The app started: restore a stored session, if any.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

/// The repository started a session: the user signed in or signed up.
final class _AuthSessionStarted extends AuthEvent {
  const _AuthSessionStarted(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

/// The repository changed the signed-in user's details, for example the email.
final class _AuthUserUpdated extends AuthEvent {
  const _AuthUserUpdated(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

/// The repository ended the session, for example after a failed refresh.
final class _AuthSessionExpired extends AuthEvent {
  const _AuthSessionExpired();
}

/// The repository deleted the account and cleared the local session.
final class _AuthAccountDeleted extends AuthEvent {
  const _AuthAccountDeleted();
}

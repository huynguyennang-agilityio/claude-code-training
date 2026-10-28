import '../entities/auth_user.dart';
import '../failures/auth_failure.dart';

/// Signs users in and out and keeps their session.
///
/// Every method throws [AuthFailure] on error. Tokens never leave the data
/// layer: callers only see the signed-in [AuthUser].
abstract interface class AuthRepository {
  /// The user from the stored session, or null when no one is signed in.
  Future<AuthUser?> restoreSession();

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthUser> signIn({required String email, required String password});

  /// Changes the account email (`PUT /users/me/email`) and returns the updated
  /// user, also announced on [userUpdated].
  ///
  /// Extra failures: [AuthFailureCode.incorrectPassword] (403),
  /// [AuthFailureCode.emailTaken] (409), [AuthFailureCode.validation] (422)
  /// and [AuthFailureCode.rateLimited] (429, with `retryAfter`).
  Future<AuthUser> changeEmail({
    required String newEmail,
    required String currentPassword,
  });

  /// Changes the password (`PUT /users/me/password`). The backend revokes
  /// every refresh token and answers with a new pair; the repository stores
  /// it before it returns, so the next request already uses it.
  ///
  /// Extra failures: [AuthFailureCode.incorrectPassword] (403),
  /// [AuthFailureCode.validation] (422, `new_password`) and
  /// [AuthFailureCode.rateLimited] (429, with `retryAfter`).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Clears the local session and revokes the refresh token on the backend.
  Future<void> signOut();

  /// Emits the user after a successful sign in or sign up, so whatever owns the
  /// session state (the `AuthBloc`) learns of it without the sign-in and
  /// sign-up forms having to tell it.
  Stream<AuthUser> get sessionStarted;

  /// Emits the signed-in user after their account changed (a new email), so
  /// the `AuthBloc` shows it without the form that made the change telling it.
  Stream<AuthUser> get userUpdated;

  /// Emits when the session ends without the user signing out, for example
  /// when a token refresh fails.
  Stream<void> get sessionExpired;
}

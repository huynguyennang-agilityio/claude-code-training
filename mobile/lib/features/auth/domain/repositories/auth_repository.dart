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

  /// Clears the local session and revokes the refresh token on the backend.
  Future<void> signOut();

  /// Emits when the session ends without the user signing out, for example
  /// when a token refresh fails.
  Stream<void> get sessionExpired;
}

import 'auth_failure.dart';
import 'auth_models.dart';

/// Talks to the backend `/auth/*` endpoints.
///
/// Every method throws [AuthFailure] on error.
abstract interface class AuthRepository {
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthSession> signIn({required String email, required String password});

  /// Exchanges [refreshToken] for a new pair of tokens.
  Future<AuthTokens> refresh(String refreshToken);

  /// Revokes [refreshToken] on the backend.
  Future<void> signOut(String refreshToken);
}

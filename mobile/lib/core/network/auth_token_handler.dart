/// What [AuthInterceptor] needs from the auth feature, so `core/` does not
/// depend on it.
abstract interface class AuthTokenHandler {
  /// The current access token, or null when no one is signed in.
  Future<String?> accessToken();

  /// Swaps the stored refresh token for a new token pair.
  ///
  /// Returns false when there is no session or the backend rejects the
  /// refresh token.
  Future<bool> refreshTokens();

  /// Clears the stored session after a failed refresh and tells the app the
  /// user has been signed out.
  Future<void> expireSession();
}

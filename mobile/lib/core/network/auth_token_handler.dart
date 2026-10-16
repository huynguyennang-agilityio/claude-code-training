/// The outcome of [AuthTokenHandler.refreshTokens].
enum TokenRefreshResult {
  /// A new token pair is stored.
  refreshed,

  /// The backend rejected the refresh token (`invalid_refresh_token`): the
  /// session is over.
  rejected,

  /// Nothing changed: no one is signed in, or the refresh failed for a reason
  /// that says nothing about the token (network, rate limit, server error).
  /// Keep the session and report the original error.
  notRefreshed,
}

/// What [AuthInterceptor] needs from the auth feature, so `core/` does not
/// depend on it.
abstract interface class AuthTokenHandler {
  /// The current access token, or null when no one is signed in.
  Future<String?> accessToken();

  /// Swaps the stored refresh token for a new token pair.
  Future<TokenRefreshResult> refreshTokens();

  /// Clears the stored session after a rejected refresh and tells the app the
  /// user has been signed out.
  Future<void> expireSession();
}

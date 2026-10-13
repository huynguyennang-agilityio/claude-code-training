/// Why an auth request failed, mapped from the backend's `error.code`.
///
/// See `docs/api/auth.md` for the full list of codes.
enum AuthFailureCode {
  validation('validation_error', 'Check the highlighted fields.'),
  emailTaken('email_taken', 'An account with this email already exists.'),
  invalidCredentials(
    'invalid_credentials',
    'The email or password is incorrect.',
  ),
  invalidRefreshToken(
    'invalid_refresh_token',
    'Your session has expired. Sign in again.',
  ),
  notAuthenticated('not_authenticated', 'Sign in to continue.'),
  invalidToken('invalid_token', 'Your session has expired. Sign in again.'),
  tokenExpired('token_expired', 'Your session has expired. Sign in again.'),
  rateLimited(
    'rate_limited',
    'Too many attempts. Wait a few minutes and try again.',
  ),
  network('network', 'Cannot reach StrideQuest. Check your connection.'),
  unknown('unknown', 'Something went wrong. Try again.');

  const AuthFailureCode(this.wireCode, this.defaultMessage);

  /// The code the backend sends in `error.code`.
  final String wireCode;

  /// A message that is safe to show the user.
  final String defaultMessage;

  static AuthFailureCode fromWire(String? code) {
    return values.firstWhere(
      (value) => value.wireCode == code,
      orElse: () => unknown,
    );
  }
}

/// A typed auth error. [message] is always safe to show the user.
class AuthFailure implements Exception {
  AuthFailure(this.code, {this.fieldErrors = const {}})
    : message = code.defaultMessage;

  final AuthFailureCode code;
  final String message;

  /// Per-field messages from a `validation_error`, keyed by field name
  /// (for example `password`).
  final Map<String, String> fieldErrors;

  @override
  String toString() => 'AuthFailure(${code.wireCode})';
}

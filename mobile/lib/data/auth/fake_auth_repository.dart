import 'auth_failure.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

/// In-memory [AuthRepository] that behaves like the backend.
///
/// Used by tests, and by local app builds once the app wiring lands (#14),
/// until the backend auth endpoints exist.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.latency = Duration.zero});

  /// Delay added to every call, so loading states can be seen in the UI.
  final Duration latency;

  final _users = <String, ({AuthUser user, String password})>{};
  final _refreshTokens = <String, AuthUser>{};
  var _nextId = 1;
  var _tokenCounter = 0;

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await Future<void>.delayed(latency);
    final key = email.trim().toLowerCase();
    final fieldErrors = _validateSignUp(key, password, displayName.trim());
    if (fieldErrors.isNotEmpty) {
      throw AuthFailure(AuthFailureCode.validation, fieldErrors: fieldErrors);
    }
    if (_users.containsKey(key)) {
      throw AuthFailure(AuthFailureCode.emailTaken);
    }
    final user = AuthUser(
      id: 'fake-user-${_nextId++}',
      email: key,
      displayName: displayName.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    _users[key] = (user: user, password: password);
    return AuthSession(user: user, tokens: _issueTokens(user));
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final account = _users[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw AuthFailure(AuthFailureCode.invalidCredentials);
    }
    return AuthSession(user: account.user, tokens: _issueTokens(account.user));
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    await Future<void>.delayed(latency);
    final user = _refreshTokens.remove(refreshToken);
    if (user == null) {
      throw AuthFailure(AuthFailureCode.invalidRefreshToken);
    }
    return _issueTokens(user);
  }

  @override
  Future<void> signOut(String refreshToken) async {
    await Future<void>.delayed(latency);
    _refreshTokens.remove(refreshToken);
  }

  /// Applies the field rules from `docs/api/auth.md`, like the backend does
  /// before it checks for a duplicate email.
  Map<String, String> _validateSignUp(
    String email,
    String password,
    String displayName,
  ) {
    return {
      if (email.length > 254 ||
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
        'email': 'Enter a valid email address.',
      if (password.length < 8 ||
          password.length > 128 ||
          !password.contains(RegExp('[A-Za-z]')) ||
          !password.contains(RegExp('[0-9]')))
        'password':
            'Password must be 8 to 128 characters with a letter and a digit.',
      if (displayName.isEmpty || displayName.length > 50)
        'display_name': 'Display name must be 1 to 50 characters.',
    };
  }

  AuthTokens _issueTokens(AuthUser user) {
    _tokenCounter++;
    final refreshToken = 'fake-refresh-${user.id}-$_tokenCounter';
    _refreshTokens[refreshToken] = user;
    return AuthTokens(
      accessToken: 'fake-access-${user.id}-$_tokenCounter',
      refreshToken: refreshToken,
    );
  }
}

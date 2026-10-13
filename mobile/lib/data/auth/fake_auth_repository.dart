import 'auth_failure.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

/// In-memory [AuthRepository] that behaves like the backend.
///
/// Used by tests and by local builds started with
/// `--dart-define=FAKE_AUTH=true` until the backend auth endpoints exist.
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
    if (_users.containsKey(key)) {
      throw AuthFailure(AuthFailureCode.emailTaken);
    }
    if (password.length < 8) {
      throw AuthFailure(
        AuthFailureCode.validation,
        fieldErrors: {'password': 'Password must be at least 8 characters.'},
      );
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

import '../../domain/failures/auth_failure.dart';
import '../models/auth_session_model.dart';
import '../models/auth_user_model.dart';
import '../models/token_pair_model.dart';
import 'auth_remote_data_source.dart';

/// In-memory [AuthRemoteDataSource] that behaves like the backend.
///
/// Used by tests, and by debug builds run with `--dart-define=API_MODE=mock`
/// (registered in `MockApiModule`).
/// Like the backend, sign in returns
/// `validation_error` for a malformed body and `rate_limited` after
/// [maxFailedSignIns] failed attempts for one email within
/// [signInFailureWindow]. The per-IP limit is not modelled.
class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  FakeAuthRemoteDataSource({
    this.latency = Duration.zero,
    DateTime Function()? now,
    Set<String> lastAdminEmails = const {},
  }) : _now = now ?? DateTime.now,
       _lastAdminEmails = {...lastAdminEmails};

  static const maxFailedSignIns = 5;
  static const signInFailureWindow = Duration(minutes: 15);

  /// An email that already has an account, so the taken-email error can be
  /// seen in mock mode without a second sign up.
  static const takenEmail = 'taken@example.com';

  static const _accessTokenLifetime = Duration(minutes: 15);

  /// Delay added to every call, so loading states can be seen in the UI.
  final Duration latency;

  final DateTime Function() _now;

  /// Emails the fake treats as the only remaining admin: deleting them fails
  /// with `last_admin`.
  final Set<String> _lastAdminEmails;
  final _users = <String, ({AuthUserModel user, String password})>{};
  final _failedSignIns = <String, List<DateTime>>{};
  final _refreshTokens = <String, AuthUserModel>{};
  // The user of the latest session: the fake has no access token to look up.
  AuthUserModel? _currentUser;
  var _nextId = 1;
  var _tokenCounter = 0;

  @override
  Future<AuthSessionModel> signUp({
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
    final user = AuthUserModel(
      id: 'fake-user-${_nextId++}',
      email: key,
      displayName: displayName.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    _users[key] = (user: user, password: password);
    return AuthSessionModel(user: user, tokens: _issueTokens(user));
  }

  @override
  Future<AuthSessionModel> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final key = email.trim().toLowerCase();
    final fieldErrors = {
      if (!_isValidEmail(key)) 'email': 'Enter a valid email address.',
      if (password.isEmpty) 'password': 'Enter your password.',
    };
    if (fieldErrors.isNotEmpty) {
      throw AuthFailure(AuthFailureCode.validation, fieldErrors: fieldErrors);
    }

    final failures = _recentFailures(key);
    if (failures.length >= maxFailedSignIns) {
      throw AuthFailure(
        AuthFailureCode.rateLimited,
        retryAfter: failures.first.add(signInFailureWindow).difference(_now()),
      );
    }
    final account = _users[key];
    if (account == null || account.password != password) {
      failures.add(_now());
      throw AuthFailure(AuthFailureCode.invalidCredentials);
    }
    _failedSignIns.remove(key);
    return AuthSessionModel(
      user: account.user,
      tokens: _issueTokens(account.user),
    );
  }

  @override
  Future<TokenPairModel> refresh(String refreshToken) async {
    await Future<void>.delayed(latency);
    final user = _refreshTokens.remove(refreshToken);
    if (user == null) {
      throw AuthFailure(AuthFailureCode.invalidRefreshToken);
    }
    return _issueTokens(user);
  }

  /// Checks like the backend, in the order of `docs/api/auth.md`: field rules
  /// (422), the current password (403, and 429 after [maxFailedSignIns] wrong
  /// ones), the same email (422), an email another account has (409).
  @override
  Future<AuthUserModel> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    await Future<void>.delayed(latency);
    final current = _currentUser;
    if (current == null) throw AuthFailure(AuthFailureCode.notAuthenticated);
    final key = newEmail.trim().toLowerCase();
    if (!_isValidEmail(key)) {
      throw AuthFailure(
        AuthFailureCode.validation,
        fieldErrors: const {'new_email': 'Enter a valid email address.'},
      );
    }

    final failures = _recentFailures(current.email);
    if (failures.length >= maxFailedSignIns) {
      throw AuthFailure(
        AuthFailureCode.rateLimited,
        retryAfter: failures.first.add(signInFailureWindow).difference(_now()),
      );
    }
    final account = _users[current.email];
    if (account == null || account.password != currentPassword) {
      failures.add(_now());
      throw AuthFailure(AuthFailureCode.incorrectPassword);
    }
    _failedSignIns.remove(current.email);

    if (key == current.email) {
      throw AuthFailure(
        AuthFailureCode.validation,
        fieldErrors: const {
          'new_email': 'New email must differ from the current email.',
        },
      );
    }
    if (key == takenEmail || _users.containsKey(key)) {
      throw AuthFailure(AuthFailureCode.emailTaken);
    }
    final user = current.copyWith(email: key);
    _users
      ..remove(current.email)
      ..[key] = (user: user, password: account.password);
    for (final entry in _refreshTokens.entries.toList()) {
      if (entry.value.id == user.id) _refreshTokens[entry.key] = user;
    }
    return _currentUser = user;
  }

  /// Checks like the backend, in the order of `docs/api/auth.md` as changed by
  /// #124 (PR #142): field rules
  /// (422), the rate limit (429), the current password (403), the same
  /// password (422, naming `new_password`). On success every refresh token of
  /// the user is revoked and a new pair is issued.
  @override
  Future<TokenPairModel> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(latency);
    final current = _currentUser;
    if (current == null) throw AuthFailure(AuthFailureCode.notAuthenticated);
    if (!_isValidPassword(newPassword)) {
      throw AuthFailure(
        AuthFailureCode.validation,
        fieldErrors: const {'new_password': _passwordRule},
      );
    }

    final failures = _recentFailures(current.email);
    if (failures.length >= maxFailedSignIns) {
      throw AuthFailure(
        AuthFailureCode.rateLimited,
        retryAfter: failures.first.add(signInFailureWindow).difference(_now()),
      );
    }
    final account = _users[current.email];
    if (account == null || account.password != currentPassword) {
      failures.add(_now());
      throw AuthFailure(AuthFailureCode.incorrectPassword);
    }
    _failedSignIns.remove(current.email);

    if (newPassword == currentPassword) {
      throw AuthFailure(
        AuthFailureCode.validation,
        fieldErrors: const {
          'new_password': 'New password must differ from the current password.',
        },
      );
    }
    _users[current.email] = (user: account.user, password: newPassword);
    _refreshTokens.removeWhere((_, user) => user.id == current.id);
    return _issueTokens(current);
  }

  /// Checks like the backend, in the order of `docs/api/auth.md`: the field
  /// rule (422), the rate
  /// limit (429), the current password (403), the last admin (409). On success
  /// the user and their refresh tokens are gone.
  @override
  Future<void> deleteAccount({required String currentPassword}) async {
    await Future<void>.delayed(latency);
    final current = _currentUser;
    if (current == null) throw AuthFailure(AuthFailureCode.notAuthenticated);
    if (currentPassword.isEmpty || currentPassword.length > 128) {
      throw AuthFailure(
        AuthFailureCode.validation,
        fieldErrors: const {
          'current_password':
              'Enter your current password (up to 128 '
              'characters).',
        },
      );
    }

    final failures = _recentFailures(current.email);
    if (failures.length >= maxFailedSignIns) {
      throw AuthFailure(
        AuthFailureCode.rateLimited,
        retryAfter: failures.first.add(signInFailureWindow).difference(_now()),
      );
    }
    final account = _users[current.email];
    if (account == null || account.password != currentPassword) {
      failures.add(_now());
      throw AuthFailure(AuthFailureCode.incorrectPassword);
    }
    _failedSignIns.remove(current.email);

    if (_lastAdminEmails.contains(current.email)) {
      throw AuthFailure(AuthFailureCode.lastAdmin);
    }
    _users.remove(current.email);
    _refreshTokens.removeWhere((_, user) => user.id == current.id);
    _currentUser = null;
  }

  @override
  Future<void> signOut(String refreshToken) async {
    await Future<void>.delayed(latency);
    final user = _refreshTokens.remove(refreshToken);
    if (user != null && user.id == _currentUser?.id) _currentUser = null;
  }

  /// Applies the field rules from `docs/api/auth.md`, like the backend does
  /// before it checks for a duplicate email.
  Map<String, String> _validateSignUp(
    String email,
    String password,
    String displayName,
  ) {
    return {
      if (!_isValidEmail(email)) 'email': 'Enter a valid email address.',
      if (!_isValidPassword(password)) 'password': _passwordRule,
      if (displayName.isEmpty || displayName.length > 50)
        'display_name': 'Display name must be 1 to 50 characters.',
    };
  }

  static const _passwordRule =
      'Password must be 8 to 128 characters with a letter and a digit.';

  bool _isValidPassword(String password) {
    return password.length >= 8 &&
        password.length <= 128 &&
        password.contains(RegExp('[A-Za-z]')) &&
        password.contains(RegExp('[0-9]'));
  }

  bool _isValidEmail(String email) {
    return email.length <= 254 &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  /// Failed sign-ins for [email] inside the window, oldest first.
  List<DateTime> _recentFailures(String email) {
    final cutoff = _now().subtract(signInFailureWindow);
    return (_failedSignIns[email] ??= [])
      ..removeWhere((time) => !time.isAfter(cutoff));
  }

  TokenPairModel _issueTokens(AuthUserModel user) {
    _tokenCounter++;
    final refreshToken = 'fake-refresh-${user.id}-$_tokenCounter';
    _refreshTokens[refreshToken] = user;
    _currentUser = user;
    return TokenPairModel(
      accessToken: 'fake-access-${user.id}-$_tokenCounter',
      refreshToken: refreshToken,
      expiresIn: _accessTokenLifetime,
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/config/app_config.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_banner.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';

/// The Delete Account screen in the real app against the real backend: each
/// documented refusal (`incorrect_password`, `rate_limited`, `last_admin`)
/// shown in the banner, the disabled button that blocks both `422` triggers
/// (an empty password and one over 128 characters) so a `422` cannot be sent
/// from the UI (its mapping is checked by the remote data source unit test),
/// the delete itself (this device and a second one on the API), and a
/// second device in the app that finds out at its next request.
///
/// Needs the API running at `API_BASE_URL` (see `sign_in_flow_test.dart`), a
/// simulator or emulator, and the email of the ONLY admin of that database in
/// `LAST_ADMIN_EMAIL` (password `run4medals`). The test submits that
/// account's right password and expects `409`; if another admin exists, the
/// account IS deleted. So run it against a fresh database of its own (for
/// example a backend on port 8001 on `stridequest_i<issue>_dev` after
/// `alembic upgrade head`, with one account made admin by
/// `python -m app.scripts.create_admin`), never the shared dev database:
///
///     flutter test integration_test/delete_account_flow_test.dart -d <device id> \
///       --dart-define=API_BASE_URL=http://127.0.0.1:8001/api/v1/ \
///       --dart-define=LAST_ADMIN_EMAIL=<the only admin's email>
///
/// The test creates its other users, so it can be run again. Not many times in
/// a row, though: each run makes 7 failed password attempts from 127.0.0.1
/// (1 + 5 for the `403` and `429` users, 1 for the deleted account's sign in),
/// and the backend allows 20 per IP in 15 minutes, so do not run it more than
/// about twice in 15 minutes.

const _lastAdminEmail = String.fromEnvironment('LAST_ADMIN_EMAIL');
const _password = 'run4medals';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for ${finder.describeMatch(Plurality.one)}.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final _api = Dio(
  BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    // Every status is a result to assert on, not an exception.
    validateStatus: (_) => true,
  ),
);

Future<String> _signUp(String label) async {
  final email =
      'it-da-$label-${DateTime.now().microsecondsSinceEpoch}@example.com';
  final response = await _api.post<void>(
    'auth/signup',
    data: {
      'email': email,
      'password': _password,
      'display_name': 'Delete Runner',
    },
  );
  expect(response.statusCode, 201);
  return email;
}

/// Signs in on the API (a "device" besides the app) and returns the tokens.
Future<Map<String, dynamic>> _apiSignIn(String email) async {
  final response = await _api.post<Map<String, dynamic>>(
    'auth/signin',
    data: {'email': email, 'password': _password},
  );
  expect(response.statusCode, 200);
  return response.data!['tokens'] as Map<String, dynamic>;
}

Options _bearer(Map<String, dynamic> tokens) =>
    Options(headers: {'Authorization': 'Bearer ${tokens['access_token']}'});

Future<Response<Map<String, dynamic>>> _apiDelete(
  Map<String, dynamic> tokens,
  String password,
) => _api.post<Map<String, dynamic>>(
  'users/me/delete',
  data: {'current_password': password},
  options: _bearer(tokens),
);

String? _errorCode(Response<Map<String, dynamic>> response) {
  final error = response.data?['error'];
  return error is Map<String, dynamic> ? error['code'] as String? : null;
}

Future<void> _launchApp(WidgetTester tester) async {
  await getIt.reset();
  configureDependencies();
  addTearDown(getIt.reset);
  // The device may still hold the session of an earlier run.
  await getIt<AuthRepository>().signOut();
  final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
  await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
  await tester.pumpAndSettle();
}

Future<void> _signInToTabs(
  WidgetTester tester,
  String email, {
  String password = _password,
}) async {
  await typeInto(tester, find.widgetWithText(AuthTextField, 'Email'), email);
  await typeInto(
    tester,
    find.widgetWithText(AuthTextField, 'Password'),
    password,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await pumpUntilFound(tester, find.byType(NavigationBar));
}

Future<void> _openDeleteAccount(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Profile'),
    ),
  );
  await tester.pumpAndSettle();
  await tapVisible(tester, find.widgetWithText(TextButton, 'Delete account'));
  await pumpUntilFound(tester, find.text('Current Password'));
}

final _deleteButton = find.widgetWithText(FilledButton, 'Delete account');

Future<void> _submit(WidgetTester tester, String password) async {
  await typeInto(tester, find.byType(TextField).first, password);
  await tapVisible(tester, _deleteButton);
}

bool _deleteEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_deleteButton).onPressed != null;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a refused delete stays on the screen, signed in', (
    tester,
  ) async {
    final email = await _signUp('refused');
    await _launchApp(tester);
    await _signInToTabs(tester, email);
    await _openDeleteAccount(tester);

    // 1. `422` cannot be sent: the button waits for a password of 1 to 128
    // characters (an empty one and a longer one are the two triggers).
    expect(_deleteEnabled(tester), isFalse);
    await typeInto(tester, find.byType(TextField).first, 'x');
    expect(_deleteEnabled(tester), isTrue);
    await typeInto(tester, find.byType(TextField).first, 'x' * 129);
    expect(_deleteEnabled(tester), isFalse);
    expect(find.text('Passwords are up to 128 characters.'), findsOneWidget);
    await typeInto(tester, find.byType(TextField).first, 'x' * 128);
    expect(_deleteEnabled(tester), isTrue);
    expect(find.text('Passwords are up to 128 characters.'), findsNothing);
    await typeInto(tester, find.byType(TextField).first, '');
    expect(_deleteEnabled(tester), isFalse);

    // 2. `403 incorrect_password`: a banner, same screen, still signed in.
    await _submit(tester, 'wrongpass1');
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(AuthBanner),
        matching: find.text('The current password is incorrect.'),
      ),
    );
    expect(find.text('Current Password'), findsOneWidget);
    expect(getIt<AuthBloc>().state, isA<AuthAuthenticated>());
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
  });

  testWidgets('five wrong passwords rate-limit the delete: 429 with the wait', (
    tester,
  ) async {
    // A user of its own, so the other tests are not blocked. One wrong attempt
    // in the app and four from the API make the five; the next request is
    // `429` even with the right password.
    final email = await _signUp('limited');
    await _launchApp(tester);
    await _signInToTabs(tester, email);
    await _openDeleteAccount(tester);
    await _submit(tester, 'wrongpass1');
    await pumpUntilFound(
      tester,
      find.text('The current password is incorrect.'),
    );
    for (var i = 0; i < 4; i++) {
      final response = await _api.post<void>(
        'auth/signin',
        data: {'email': email, 'password': 'wrongpass1'},
      );
      expect(response.statusCode, 401);
    }
    await _submit(tester, _password);
    await pumpUntilFound(
      tester,
      find.textContaining('Too many attempts. Wait a few minutes'),
    );
    expect(find.textContaining('Try again in 15 minutes.'), findsOneWidget);
    expect(getIt<AuthBloc>().state, isA<AuthAuthenticated>());
  });

  testWidgets('the only admin cannot delete the account: 409', (tester) async {
    if (_lastAdminEmail.isEmpty) {
      fail(
        'Pass the email of the only admin of the test database with '
        '--dart-define=LAST_ADMIN_EMAIL=<email> (password $_password).',
      );
    }
    // The API cannot list admins, so only the role is checked here. If another
    // admin exists, the submit below deletes this account for good.
    final adminTokens = await _apiSignIn(_lastAdminEmail);
    final admin = await _api.get<Map<String, dynamic>>(
      'users/me',
      options: _bearer(adminTokens),
    );
    if (admin.data?['role'] != 'admin') {
      fail('LAST_ADMIN_EMAIL ($_lastAdminEmail) is not an admin.');
    }
    await _launchApp(tester);
    await _signInToTabs(tester, _lastAdminEmail);
    await _openDeleteAccount(tester);
    await _submit(tester, _password);
    await pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(AuthBanner),
        matching: find.text(AuthFailureCode.lastAdmin.defaultMessage),
      ),
    );
    expect(
      find.text(
        "You're the only admin. Make another account an admin before "
        'deleting yours.',
      ),
      findsOneWidget,
    );
    expect(find.text('Current Password'), findsOneWidget);
    expect(getIt<AuthBloc>().state, isA<AuthAuthenticated>());

    // The account still exists.
    final tokens = await _apiSignIn(_lastAdminEmail);
    final me = await _api.get<Map<String, dynamic>>(
      'users/me',
      options: _bearer(tokens),
    );
    expect(me.statusCode, 200);
  });

  testWidgets('a delete ends the account on every device', (tester) async {
    final email = await _signUp('delete');
    // The second device: the same user, signed in on the API.
    final other = await _apiSignIn(email);
    expect(
      (await _api.get<void>('users/me', options: _bearer(other))).statusCode,
      200,
    );

    await _launchApp(tester);
    await _signInToTabs(tester, email);
    await _openDeleteAccount(tester);
    await _submit(tester, _password);

    // This device: back on Sign in, with the notice.
    await pumpUntilFound(tester, find.widgetWithText(FilledButton, 'Sign in'));
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(getIt<AuthBloc>().state, isA<AuthUnauthenticated>());

    // The account is gone: its password no longer signs in.
    final signIn = await _api.post<Map<String, dynamic>>(
      'auth/signin',
      data: {'email': email, 'password': _password},
    );
    expect(signIn.statusCode, 401);
    expect(_errorCode(signIn), 'invalid_credentials');

    // The second device's access token is refused ...
    final me = await _api.get<Map<String, dynamic>>(
      'users/me',
      options: _bearer(other),
    );
    expect(me.statusCode, 401);
    expect(_errorCode(me), 'invalid_token');

    // ... and so is its refresh token.
    final refresh = await _api.post<Map<String, dynamic>>(
      'auth/refresh',
      data: {'refresh_token': other['refresh_token']},
    );
    expect(refresh.statusCode, 401);
    expect(_errorCode(refresh), 'invalid_refresh_token');
  });

  testWidgets('a delete on another device ends the session of the app', (
    tester,
  ) async {
    final email = await _signUp('other');
    await _launchApp(tester);
    await _signInToTabs(tester, email);

    // The other device deletes the account.
    final other = await _apiSignIn(email);
    final deleted = await _apiDelete(other, _password);
    expect(deleted.statusCode, 204);

    // The app's next authenticated request (the Profile info form reads
    // `GET /users/me/profile`) gets `401 invalid_token`, the refresh is
    // refused and the session ends as an expired one, not as "deleted".
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(
      tester,
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Profile'),
      ),
    );
    await pumpUntilFound(tester, find.widgetWithText(FilledButton, 'Sign in'));
    expect(
      find.text('Your session has expired. Sign in again.'),
      findsOneWidget,
    );
    expect(find.text('Your account has been deleted.'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(getIt<AuthBloc>().state, isA<AuthUnauthenticated>());
  });
}

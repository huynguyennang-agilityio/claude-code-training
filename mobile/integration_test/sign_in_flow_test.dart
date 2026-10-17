import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/config/app_config.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';

/// The sign-in and sign-up flows in the real app against the real backend.
///
/// Needs the API running at `API_BASE_URL` (default `http://localhost:8000/api/v1/`,
/// which a simulator reaches on the host) and a simulator or emulator:
///
///     flutter test integration_test/sign_in_flow_test.dart -d <device id>
///
/// The test creates its own user, so it can be run again and again.
/// Pumps until [finder] matches, or fails after [timeout].
///
/// A real network call finishes in real time, and `pumpAndSettle` can return
/// before the request has even started, so wait for what the screen should show.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
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

/// Types [text] into the field [finder] matches, replacing what is there.
///
/// Taps the field first: on a device, `enterText` alone can leave the old text
/// in a field that already has focus.
Future<void> typeInto(WidgetTester tester, Finder finder, String text) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a user signs in, is greeted, and signs out', (tester) async {
    final email = 'it-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'run4medals';
    await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)).post<void>(
      'auth/signup',
      data: {
        'email': email,
        'password': password,
        'display_name': 'Integration Runner',
      },
    );

    await getIt.reset();
    configureDependencies();
    addTearDown(getIt.reset);
    final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
    await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
    await tester.pumpAndSettle();

    // Signed out: the app starts on Sign in.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Every run is a quest.'), findsNothing);

    // A wrong password is refused with the documented message.
    final emailField = find.widgetWithText(AuthTextField, 'Email');
    final passwordField = find.widgetWithText(AuthTextField, 'Password');
    await typeInto(tester, emailField, email);
    await typeInto(tester, passwordField, 'wrong-pass1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await pumpUntilFound(
      tester,
      find.text(AuthFailureCode.invalidCredentials.defaultMessage),
    );

    // The right one reaches Home, which greets the user by name.
    await typeInto(tester, passwordField, password);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await pumpUntilFound(
      tester,
      find.text('Welcome back, Integration Runner.'),
    );
    expect(find.text('Welcome back'), findsNothing);

    // Sign out returns to Sign in.
    await tester.tap(find.byTooltip('Sign out'));
    await pumpUntilFound(tester, find.text('Welcome back'));
    expect(find.textContaining('Welcome back,'), findsNothing);
  });

  testWidgets(
    'a new user signs up, is signed in, and a taken email is refused',
    (tester) async {
      final email =
          'it-up-${DateTime.now().millisecondsSinceEpoch}@example.com';
      const password = 'run4medals';
      await getIt.reset();
      configureDependencies();
      addTearDown(getIt.reset);
      final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
      await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
      await tester.pumpAndSettle();

      // Sign in -> Sign up.
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);

      final nameField = find.widgetWithText(AuthTextField, 'Display name');
      final emailField = find.widgetWithText(AuthTextField, 'Email');
      final passwordField = find.widgetWithText(AuthTextField, 'Password');
      await typeInto(tester, nameField, 'Signup Runner');
      await typeInto(tester, emailField, email);
      await typeInto(tester, passwordField, password);
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await pumpUntilFound(tester, find.text('Welcome back, Signup Runner.'));

      // Sign out, then the same email is refused on the email field.
      await tester.tap(find.byTooltip('Sign out'));
      await pumpUntilFound(tester, find.text('Welcome back'));
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      await typeInto(tester, nameField, 'Another Runner');
      await typeInto(tester, emailField, email);
      await typeInto(tester, passwordField, password);
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await pumpUntilFound(
        tester,
        find.text(AuthFailureCode.emailTaken.defaultMessage),
      );
      expect(find.text('Create your account'), findsOneWidget);
    },
  );
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/config/app_config.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_banner.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';

/// The Email screen in the real app against the real backend: change the
/// email, sign out and in with the new one, then each documented refusal
/// (`incorrect_password`, `email_taken`, a field error, `rate_limited`) shown
/// where the user can fix it.
///
/// Needs the API running at `API_BASE_URL` (see `sign_in_flow_test.dart`) and
/// a simulator or emulator:
///
///     flutter test integration_test/change_email_flow_test.dart -d <device id> \
///       --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/
///
/// The test creates its own users, so it can be run again. Not many times in a
/// row, though: each run makes 5 failed password attempts from 127.0.0.1, and
/// the backend allows 20 per IP in 15 minutes, so do not run it more than
/// about 3 times in 15 minutes (the 429 would then come earlier than the test
/// expects).

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a user changes the email and meets every refusal', (
    tester,
  ) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'it-ce-$stamp@example.com';
    final newEmail = 'it-ce-$stamp-new@example.com';
    final takenEmail = 'it-ce-$stamp-taken@example.com';
    const password = 'run4medals';
    final api = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    for (final address in [email, takenEmail]) {
      await api.post<void>(
        'auth/signup',
        data: {
          'email': address,
          'password': password,
          'display_name': 'Email Runner',
        },
      );
    }

    await getIt.reset();
    configureDependencies();
    addTearDown(getIt.reset);
    // The device may still hold the session of an earlier run.
    await getIt<AuthRepository>().signOut();
    final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
    await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
    await tester.pumpAndSettle();

    Future<void> signIn(String address) async {
      await typeInto(
        tester,
        find.widgetWithText(AuthTextField, 'Email'),
        address,
      );
      await typeInto(
        tester,
        find.widgetWithText(AuthTextField, 'Password'),
        password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await pumpUntilFound(tester, find.byType(NavigationBar));
    }

    Future<void> openEmail() async {
      // The snackbar of the last save would cover the next form.
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Email'),
        ),
      );
      await pumpUntilFound(tester, find.text('Email address'));
    }

    // The two text fields of the form, in order.
    final emailInput = find.byType(TextField).at(0);
    final passwordInput = find.byType(TextField).at(1);

    Future<void> submit(String address, String pass) async {
      await typeInto(tester, emailInput, address);
      await typeInto(tester, passwordInput, pass);
      await tapVisible(tester, find.text('Save'));
    }

    await signIn(email);

    // 1. Change the email: success, back on the Profile tab.
    await openEmail();
    await submit(newEmail, password);
    await pumpUntilFound(tester, find.text('Email changed to $newEmail'));
    await pumpUntilFound(tester, find.byType(NavigationBar));
    expect(find.text('Email address'), findsNothing);

    // 2. The new email signs in.
    await tapVisible(tester, find.text('Sign out'));
    await pumpUntilFound(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await signIn(newEmail);

    // 3. A wrong password is shown under Current Password.
    await openEmail();
    await submit('it-ce-$stamp-free@example.com', 'wrongpass1');
    await pumpUntilFound(
      tester,
      find.text('The current password is incorrect.'),
    );
    expect(find.text('Email address'), findsOneWidget);
    expect(find.byType(AuthBanner), findsNothing);

    // 4. An email another account uses is shown under the email.
    await submit(takenEmail, password);
    await pumpUntilFound(
      tester,
      find.text('An account with this email already exists.'),
    );
    expect(find.text('The current password is incorrect.'), findsNothing);

    // 5. An email the app accepts and the backend refuses (`422`) shows the
    //    backend message under the email.
    await submit('a..b@example.com', password);
    await pumpUntilFound(
      tester,
      find.textContaining('An email address cannot have'),
    );
    expect(
      find.text('An account with this email already exists.'),
      findsNothing,
    );

    // 6. Five wrong passwords in the window lock the account: the sixth
    //    request is `429` even with the right password, and the banner says
    //    how long to wait. Four more wrong sign-ins add to the one of step 3.
    for (var i = 0; i < 4; i++) {
      await api.post<void>(
        'auth/signin',
        data: {'email': newEmail, 'password': 'wrongpass1'},
        options: Options(validateStatus: (status) => status == 401),
      );
    }
    await submit('it-ce-$stamp-free@example.com', password);
    await pumpUntilFound(tester, find.byType(AuthBanner));
    expect(
      find.textContaining('Too many attempts. Wait a few minutes'),
      findsOneWidget,
    );
    expect(find.textContaining('Try again in 15 minutes.'), findsOneWidget);
  });
}

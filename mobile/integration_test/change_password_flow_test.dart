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

/// The Password screen in the real app against the real backend: change the
/// password, keep working on this device, sign out and in with the new one,
/// then each documented refusal (`incorrect_password`, a field error,
/// `rate_limited`) shown where the user can fix it.
///
/// Needs the API running at `API_BASE_URL` (see `sign_in_flow_test.dart`) and
/// a simulator or emulator:
///
///     flutter test integration_test/change_password_flow_test.dart -d <device id> \
///       --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/
///
/// The test creates its own users, so it can be run again. Not many times in a
/// row, though: each run makes 7 failed password attempts from 127.0.0.1, and
/// the backend allows 20 per IP in 15 minutes, so do not run it more than
/// about twice in 15 minutes (the 429 would then come earlier than the test
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

  testWidgets('a user changes the password and meets every refusal', (
    tester,
  ) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'it-cp-$stamp@example.com';
    final limitedEmail = 'it-cp-$stamp-limited@example.com';
    const password = 'run4medals';
    const newPassword = 'newrun5medals';
    final api = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    for (final address in [email, limitedEmail]) {
      await api.post<void>(
        'auth/signup',
        data: {
          'email': address,
          'password': password,
          'display_name': 'Password Runner',
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

    Future<void> signIn(String address, String pass) async {
      await typeInto(
        tester,
        find.widgetWithText(AuthTextField, 'Email'),
        address,
      );
      await typeInto(
        tester,
        find.widgetWithText(AuthTextField, 'Password'),
        pass,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    }

    Future<void> signInToTabs(String address, String pass) async {
      await signIn(address, pass);
      await pumpUntilFound(tester, find.byType(NavigationBar));
    }

    Future<void> openProfileTab() async {
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
    }

    Future<void> openPassword() async {
      await openProfileTab();
      await tester.tap(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Password'),
        ),
      );
      await pumpUntilFound(tester, find.text('Current Password'));
    }

    // The three text fields of the form, in order.
    final currentInput = find.byType(TextField).at(0);
    final newInput = find.byType(TextField).at(1);
    final confirmInput = find.byType(TextField).at(2);

    Future<void> submit(String current, String next) async {
      await typeInto(tester, currentInput, current);
      await typeInto(tester, newInput, next);
      await typeInto(tester, confirmInput, next);
      await tapVisible(tester, find.text('Save'));
    }

    await signInToTabs(email, password);

    // 1. A wrong current password is shown under Current Password (`403`).
    await openPassword();
    await submit('wrongpass1', newPassword);
    await pumpUntilFound(
      tester,
      find.text('The current password is incorrect.'),
    );
    expect(find.text('Current Password'), findsOneWidget);
    expect(find.byType(AuthBanner), findsNothing);

    // 2. The app's own rule is the backend's, so a password it accepts and the
    //    backend refuses is the same password: `422` naming `new_password`,
    //    shown under New Password.
    await submit(password, password);
    await pumpUntilFound(
      tester,
      find.text('The new password must differ from the current one.'),
    );
    expect(find.text('The current password is incorrect.'), findsNothing);
    expect(find.byType(AuthBanner), findsNothing);

    // 3. A valid change: a message and back on the Profile tab.
    await submit(password, newPassword);
    await pumpUntilFound(tester, find.text('Password changed'));
    await pumpUntilFound(tester, find.byType(NavigationBar));
    expect(find.text('Current Password'), findsNothing);

    // 4. This device keeps working with the new token pair: an authenticated
    //    screen loads (the Profile info form reads `GET /users/me/profile`).
    await tester.tap(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Profile'),
      ),
    );
    await pumpUntilFound(tester, find.text('First Name'));
    expect(find.textContaining('went wrong'), findsNothing);
    expect(find.textContaining('session has expired'), findsNothing);
    await tester.pageBack();
    await pumpUntilFound(tester, find.byType(NavigationBar));

    // 5. Sign out. The old password no longer signs in, the new one does.
    await tapVisible(tester, find.text('Sign out'));
    await pumpUntilFound(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await signIn(email, password);
    await pumpUntilFound(
      tester,
      find.text(AuthFailureCode.invalidCredentials.defaultMessage),
    );
    await signInToTabs(email, newPassword);

    // 6. Five wrong passwords in the window lock the account: the sixth
    //    request is `429` even with the right password, and the banner says
    //    how long to wait. One wrong attempt in the app and four from the
    //    API make the five, on a user of its own so step 5 is not blocked.
    await openProfileTab();
    await tapVisible(tester, find.text('Sign out'));
    await pumpUntilFound(tester, find.widgetWithText(FilledButton, 'Sign in'));
    await signInToTabs(limitedEmail, password);
    await openPassword();
    await submit('wrongpass1', newPassword);
    await pumpUntilFound(
      tester,
      find.text('The current password is incorrect.'),
    );
    for (var i = 0; i < 4; i++) {
      await api.post<void>(
        'auth/signin',
        data: {'email': limitedEmail, 'password': 'wrongpass1'},
        options: Options(validateStatus: (status) => status == 401),
      );
    }
    await submit(password, newPassword);
    await pumpUntilFound(tester, find.byType(AuthBanner));
    expect(
      find.textContaining('Too many attempts. Wait a few minutes'),
      findsOneWidget,
    );
    expect(find.textContaining('Try again in 15 minutes.'), findsOneWidget);
  });
}

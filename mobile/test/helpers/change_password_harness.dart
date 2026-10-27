import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/theme/app_theme.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_password_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/change_password_page.dart';

import 'auth_fixtures.dart';
import 'pump_screen.dart';

/// The Password page on a real [ChangePasswordBloc] over [repository].
Widget changePasswordPage(MockAuthRepository repository) => BlocProvider(
  create: (_) => ChangePasswordBloc(repository),
  child: const ChangePasswordPage(),
);

/// A repository that accepts every password change.
MockAuthRepository changePasswordRepository() {
  final repository = MockAuthRepository();
  when(
    () => repository.changePassword(
      currentPassword: any(named: 'currentPassword'),
      newPassword: any(named: 'newPassword'),
    ),
  ).thenAnswer((_) async {});
  return repository;
}

/// Makes the next password change fail with [failure].
void failChangePassword(MockAuthRepository repository, AuthFailure failure) =>
    when(
      () => repository.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenThrow(failure);

/// Text of the screen under the Password page, to tell that the page popped.
const parentText = 'Profile tab';

/// What the `/profile` route shows, so a test can tell it from the parent.
const profileRouteText = 'Profile route';

/// Pumps the Password page pushed over a parent route under a [GoRouter], as
/// the app does, so a save can pop back to the parent. [refreshListenable] is
/// the router's, as `AuthBloc`'s stream is in the app. With [pushed] false the
/// page is the only one on the stack (a deep link).
Future<void> pumpChangePassword(
  WidgetTester tester,
  MockAuthRepository repository, {
  Size size = smallPhone,
  double textScale = 1,
  Listenable? refreshListenable,
  bool pushed = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: pushed ? '/' : ChangePasswordPage.path,
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text(parentText)),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Text(profileRouteText)),
      ),
      GoRoute(
        path: ChangePasswordPage.path,
        builder: (context, state) => changePasswordPage(repository),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  if (pushed) unawaited(router.push(ChangePasswordPage.path));
  await tester.pumpAndSettle();
}

const currentLabel = 'Current Password';
const newLabel = 'New Password';
const confirmLabel = 'Confirm Password';

/// The input box of the field labelled [label].
Finder passwordFieldFor(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

/// Whether the text field labelled [label] has the keyboard focus.
bool passwordHasFocus(WidgetTester tester, String label) => tester
    .widget<EditableText>(
      find.descendant(
        of: passwordFieldFor(label),
        matching: find.byType(EditableText),
      ),
    )
    .focusNode
    .hasFocus;

/// Types the three passwords, which turns Save on.
Future<void> fillPasswords(
  WidgetTester tester, {
  String current = 'run4medals',
  String next = 'newrun5medals',
  String? confirm,
}) async {
  await tester.enterText(passwordFieldFor(currentLabel), current);
  await tester.enterText(passwordFieldFor(newLabel), next);
  await tester.enterText(passwordFieldFor(confirmLabel), confirm ?? next);
  await tester.pumpAndSettle();
}

/// The Save button, which is the only [OutlinedButton] on the form.
Finder get savePasswordButton => find.widgetWithText(OutlinedButton, 'Save');

bool isPasswordSaveEnabled(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed !=
    null;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/theme/app_theme.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_email_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/change_email_page.dart';

import 'auth_fixtures.dart';
import 'pump_screen.dart';

/// The Email page on a real [ChangeEmailBloc] over [repository].
Widget changeEmailPage(MockAuthRepository repository) => BlocProvider(
  create: (_) => ChangeEmailBloc(repository)..add(const ChangeEmailStarted()),
  child: const ChangeEmailPage(),
);

/// A repository whose signed-in user is [testUser] and that accepts every
/// email change.
MockAuthRepository changeEmailRepository() {
  final repository = MockAuthRepository();
  when(repository.restoreSession).thenAnswer((_) async => testUser.toEntity());
  when(
    () => repository.changeEmail(
      newEmail: any(named: 'newEmail'),
      currentPassword: any(named: 'currentPassword'),
    ),
  ).thenAnswer((invocation) async {
    return testUser
        .copyWith(email: invocation.namedArguments[#newEmail] as String)
        .toEntity();
  });
  return repository;
}

/// Makes the next email change fail with [failure].
void failChangeEmail(MockAuthRepository repository, AuthFailure failure) =>
    when(
      () => repository.changeEmail(
        newEmail: any(named: 'newEmail'),
        currentPassword: any(named: 'currentPassword'),
      ),
    ).thenThrow(failure);

/// Text of the screen under the Email page, to tell that the page popped.
const parentText = 'Profile tab';

/// Pumps the Email page pushed over a parent route under a [GoRouter], as the
/// app does, so a save can pop back to the parent.
Future<void> pumpChangeEmail(
  WidgetTester tester,
  MockAuthRepository repository, {
  Size size = smallPhone,
  double textScale = 1,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text(parentText)),
      ),
      GoRoute(
        path: ChangeEmailPage.path,
        builder: (context, state) => changeEmailPage(repository),
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
  unawaited(router.push(ChangeEmailPage.path));
  await tester.pumpAndSettle();
}

const emailLabel = 'Email address';
const passwordLabel = 'Current Password';

/// The input box of the field labelled [label].
Finder fieldFor(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

/// Whether the text field labelled [label] has the keyboard focus.
bool hasFocus(WidgetTester tester, String label) => tester
    .widget<EditableText>(
      find.descendant(of: fieldFor(label), matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

/// Types a new email and a password, which turns Save on.
Future<void> fillForm(
  WidgetTester tester, {
  String email = 'new.runner@example.com',
  String password = 'run4medals',
}) async {
  await tester.enterText(fieldFor(emailLabel), email);
  await tester.enterText(fieldFor(passwordLabel), password);
  await tester.pumpAndSettle();
}

/// The Save button, which is the only [OutlinedButton] on the form.
Finder get saveButton => find.widgetWithText(OutlinedButton, 'Save');

bool isSaveEnabled(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed !=
    null;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/features/auth/data/datasources/fake_auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_in_page.dart';

import '../../../helpers/in_memory_auth_local_data_source.dart';

/// The sign-in flow through the real app, router and bloc, with an in-memory
/// backend. It exists because a widget test with a mocked bloc can't see that
/// the router really leaves the sign-in page: a page pushed over Home stayed on
/// screen after a successful sign in until this was tested end to end.
void main() {
  const email = 'runner@example.com';
  const password = 'run4medals';

  Future<void> pumpApp(WidgetTester tester) async {
    final remote = FakeAuthRemoteDataSource();
    // Real async: the fake's delay is a timer that fake time would never fire.
    await tester.runAsync(
      () => remote.signUp(
        email: email,
        password: password,
        displayName: 'Lan Runner',
      ),
    );
    final repository = AuthRepositoryImpl(
      remote,
      InMemoryAuthLocalDataSource(),
    );
    final authBloc = AuthBloc(repository)..add(const AuthStarted());
    addTearDown(authBloc.close);
    addTearDown(repository.dispose);

    await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
    await tester.pumpAndSettle();
  }

  final emailField = find.widgetWithText(TextFormField, 'Email');
  final passwordField = find.widgetWithText(TextFormField, 'Password');
  final submit = find.widgetWithText(FilledButton, 'Sign in');

  testWidgets('sign in leaves the sign-in page and greets the user', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInPage), findsOneWidget);

    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, password);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage, skipOffstage: false), findsNothing);
    expect(find.text('Welcome back, Lan Runner.'), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets('a wrong password stays on the page with the message', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, 'wrong-pass1');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('the right password works after a wrong one', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, 'wrong-pass1');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    await tester.enterText(passwordField, password);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Lan Runner.'), findsOneWidget);
  });

  testWidgets('sign out returns to the signed-out Home', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, password);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.textContaining('Welcome back,'), findsNothing);
  });

  testWidgets('Back returns from the sign-in page to Home', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage, skipOffstage: false), findsNothing);
    expect(find.text('Every run is a quest.'), findsOneWidget);
  });
}

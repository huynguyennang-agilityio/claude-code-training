import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/data/datasources/fake_auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_in_page.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenges_page.dart';

import '../../../helpers/auth_di.dart';
import '../../../helpers/in_memory_auth_local_data_source.dart';
import '../../../helpers/open_profile.dart';

/// The sign-in flow through the real app, router and bloc, with an in-memory
/// backend. It exists because a widget test with a mocked bloc can't see that
/// the router really leaves the sign-in page: a page pushed over Home stayed on
/// screen after a successful sign in until this was tested end to end.
void main() {
  const email = 'runner@example.com';
  const password = 'run4medals';

  Future<void> pumpApp(
    WidgetTester tester, {
    bool storedSession = false,
  }) async {
    final remote = FakeAuthRemoteDataSource();
    final local = InMemoryAuthLocalDataSource();
    // Real async: the fake's delay is a timer that fake time would never fire.
    final session = await tester.runAsync(
      () => remote.signUp(
        email: email,
        password: password,
        displayName: 'Lan Runner',
      ),
    );
    if (storedSession) local.session = session;
    final repository = AuthRepositoryImpl(remote, local);
    final authBloc = AuthBloc(repository)..add(const AuthStarted());
    registerAuthFormBlocs(repository);
    addTearDown(getIt.reset);
    addTearDown(authBloc.close);
    addTearDown(repository.dispose);

    await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
    await tester.pumpAndSettle();
  }

  final emailField = find.widgetWithText(AuthTextField, 'Email');
  final passwordField = find.widgetWithText(AuthTextField, 'Password');
  final submit = find.widgetWithText(FilledButton, 'Sign in');

  testWidgets('sign in leaves the sign-in page and greets the user', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(SignInPage), findsOneWidget);

    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, password);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage, skipOffstage: false), findsNothing);
    expect(find.byType(ChallengesPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await openProfile(tester);
    expect(find.text('Lan Runner'), findsOneWidget);
  });

  testWidgets('a wrong password stays on the page with the message', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, 'wrong-pass1');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('the right password works after a wrong one', (tester) async {
    await pumpApp(tester);
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, 'wrong-pass1');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    await tester.enterText(passwordField, password);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(ChallengesPage), findsOneWidget);
  });

  testWidgets('sign out returns to the signed-out Home', (tester) async {
    await pumpApp(tester);
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, password);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    await openProfile(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('the app starts on sign in, with no back button', (tester) async {
    await pumpApp(tester);

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.byType(ChallengesPage), findsNothing);
  });

  testWidgets('a stored session starts on Home', (tester) async {
    await pumpApp(tester, storedSession: true);

    expect(find.byType(SignInPage, skipOffstage: false), findsNothing);
    expect(find.byType(ChallengesPage), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/data/datasources/fake_auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_in_page.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_up_page.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenges_page.dart';

import '../../../helpers/auth_di.dart';
import '../../../helpers/in_memory_auth_local_data_source.dart';
import '../../../helpers/open_profile.dart';

/// The sign-up flow through the real app, router and bloc, with an in-memory
/// backend: sign up signs the user in and the router leaves the page, and the
/// two auth screens link to each other.
void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    bool withExistingUser = false,
  }) async {
    // A phone, so the whole form and the link under the button are on screen.
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final remote = FakeAuthRemoteDataSource();
    if (withExistingUser) {
      // Real async: the fake's delay is a timer that fake time would never fire.
      await tester.runAsync(
        () => remote.signUp(
          email: 'taken@example.com',
          password: 'run4medals',
          displayName: 'First Runner',
        ),
      );
    }
    final repository = AuthRepositoryImpl(
      remote,
      InMemoryAuthLocalDataSource(),
    );
    final authBloc = AuthBloc(repository)..add(const AuthStarted());
    registerAuthFormBlocs(repository);
    addTearDown(getIt.reset);
    addTearDown(authBloc.close);
    addTearDown(repository.dispose);

    await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
    await tester.pumpAndSettle();
  }

  final nameField = find.widgetWithText(AuthTextField, 'Display name');
  final emailField = find.widgetWithText(AuthTextField, 'Email');
  final passwordField = find.widgetWithText(AuthTextField, 'Password');
  final create = find.widgetWithText(FilledButton, 'Create account');

  Future<void> openSignUp(WidgetTester tester) async {
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpPage), findsOneWidget);
  }

  Future<void> fill(
    WidgetTester tester, {
    String email = 'new@example.com',
  }) async {
    await tester.enterText(nameField, 'Lan Runner');
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, 'run4medals');
  }

  testWidgets('sign up signs the user in and leaves the page', (tester) async {
    await pumpApp(tester);
    await openSignUp(tester);

    await fill(tester);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.byType(SignUpPage, skipOffstage: false), findsNothing);
    expect(find.byType(ChallengesPage), findsOneWidget);
    await openProfile(tester);
    expect(find.text('LR'), findsOneWidget);
  });

  testWidgets('a taken email stays on the page with the message', (
    tester,
  ) async {
    await pumpApp(tester, withExistingUser: true);
    await openSignUp(tester);

    await fill(tester, email: 'taken@example.com');
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.byType(SignUpPage), findsOneWidget);
    expect(
      find.text(AuthFailureCode.emailTaken.defaultMessage),
      findsOneWidget,
    );
  });

  testWidgets('the screens link to each other and Back goes to sign in', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSignUp(tester);

    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.byType(SignInPage), findsOneWidget);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInPage), findsOneWidget);
  });
}

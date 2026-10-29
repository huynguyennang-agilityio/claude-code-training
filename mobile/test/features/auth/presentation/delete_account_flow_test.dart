import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/data/datasources/fake_auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/delete_account_page.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_in_page.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenges_page.dart';

import '../../../helpers/auth_di.dart';
import '../../../helpers/in_memory_auth_local_data_source.dart';
import '../../../helpers/open_profile.dart';

/// Delete account through the real app, router and blocs, with an in-memory
/// backend: the router, not the page, must lead to sign in with the banner.
void main() {
  const email = 'runner@example.com';
  const password = 'run4medals';

  late FakeAuthRemoteDataSource remote;
  late InMemoryAuthLocalDataSource local;

  Future<void> pumpSignedInApp(WidgetTester tester) async {
    remote = FakeAuthRemoteDataSource();
    local = InMemoryAuthLocalDataSource();
    // Real async: the fake's delay is a timer that fake time would never fire.
    local.session = await tester.runAsync(
      () => remote.signUp(
        email: email,
        password: password,
        displayName: 'Lan Runner',
      ),
    );
    final repository = AuthRepositoryImpl(remote, local);
    final authBloc = AuthBloc(repository)..add(const AuthStarted());
    registerAuthFormBlocs(repository);
    addTearDown(getIt.reset);
    addTearDown(authBloc.close);
    addTearDown(repository.dispose);

    await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
    await tester.pumpAndSettle();
    expect(find.byType(ChallengesPage), findsOneWidget);
  }

  final passwordField = find.descendant(
    of: find.byType(DeleteAccountPage),
    matching: find.byType(TextField),
  );
  final deleteButton = find.widgetWithText(FilledButton, 'Delete account');

  Future<void> openDeleteAccount(WidgetTester tester) async {
    await openProfile(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  }

  testWidgets('deleting the account lands on sign in with the banner', (
    tester,
  ) async {
    await pumpSignedInApp(tester);
    await openDeleteAccount(tester);

    await tester.enterText(passwordField, password);
    await tester.pumpAndSettle();
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountPage, skipOffstage: false), findsNothing);
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(local.session, isNull);
  });

  testWidgets('a wrong password stays on the page with the message', (
    tester,
  ) async {
    await pumpSignedInApp(tester);
    await openDeleteAccount(tester);

    await tester.enterText(passwordField, 'wrong-pass1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountPage), findsOneWidget);
    expect(find.text('The current password is incorrect.'), findsOneWidget);
    expect(local.session, isNotNull);
  });

  testWidgets('back returns to the Profile tab', (tester) async {
    await pumpSignedInApp(tester);
    await openDeleteAccount(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Delete account'), findsOneWidget);
  });
}

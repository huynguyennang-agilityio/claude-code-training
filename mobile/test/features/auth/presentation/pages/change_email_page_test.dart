import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_email_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/change_email_page.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/change_email_harness.dart';
import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/mock_auth_bloc.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = changeEmailRepository());

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  void verifyChanged({String email = 'new.runner@example.com'}) => verify(
    () =>
        repository.changeEmail(newEmail: email, currentPassword: 'run4medals'),
  ).called(1);

  group('the form', () {
    testWidgets(
      'shows the title, the explanation, the current email and Save',
      (tester) async {
        await pumpChangeEmail(tester, repository);

        expect(find.widgetWithText(AppBar, 'Email'), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget); // pushed over the tab
        expect(
          find.text(
            'This will change the account email you use to sign in with '
            'StrideQuest and where you receive notifications.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(fieldFor(emailLabel)).controller!.text,
          'runner@example.com',
        );
        expect(find.text(passwordLabel), findsOneWidget);
        expect(saveButton, findsOneWidget);
      },
    );

    testWidgets('Save is off until the email changes, is valid and a password '
        'is entered', (tester) async {
      await pumpChangeEmail(tester, repository);
      expect(isSaveEnabled(tester), isFalse);

      await tester.enterText(fieldFor(passwordLabel), 'run4medals');
      await tester.pumpAndSettle();
      expect(isSaveEnabled(tester), isFalse, reason: 'email not changed');

      await tester.enterText(fieldFor(emailLabel), 'RUNNER@example.com');
      await tester.pumpAndSettle();
      expect(isSaveEnabled(tester), isFalse, reason: 'same email in capitals');

      await tester.enterText(fieldFor(emailLabel), 'new.runner@');
      await tester.pumpAndSettle();
      expect(isSaveEnabled(tester), isFalse, reason: 'invalid email');
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      await tester.enterText(fieldFor(emailLabel), 'new.runner@example.com');
      await tester.pumpAndSettle();
      expect(isSaveEnabled(tester), isTrue);
      expect(find.text('Enter a valid email address.'), findsNothing);

      await tester.enterText(fieldFor(passwordLabel), '');
      await tester.pumpAndSettle();
      expect(isSaveEnabled(tester), isFalse, reason: 'no password');
    });

    testWidgets('Show and Hide toggle the password', (tester) async {
      await pumpChangeEmail(tester, repository);
      bool obscured() =>
          tester.widget<TextField>(fieldFor(passwordLabel)).obscureText;

      expect(obscured(), isTrue);
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(obscured(), isFalse);
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(obscured(), isTrue);
    });

    testWidgets('Next moves to the password and Done saves', (tester) async {
      await pumpChangeEmail(tester, repository);
      await tester.tap(fieldFor(emailLabel));
      await tester.pump();
      await fillForm(tester);
      await tester.tap(fieldFor(emailLabel));
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, passwordLabel), isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // The save pops the page, which takes the keyboard focus with it.
      expect(find.text(parentText), findsOneWidget);
      verifyChanged();
    });

    testWidgets('Done with an incomplete form does not save', (tester) async {
      await pumpChangeEmail(tester, repository);
      await tester.tap(fieldFor(passwordLabel));
      await tester.enterText(fieldFor(passwordLabel), 'run4medals');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verifyNever(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          currentPassword: any(named: 'currentPassword'),
        ),
      );
    });
  });

  group('saving', () {
    testWidgets('sends the trimmed email, then shows the new address and goes '
        'back', (tester) async {
      await pumpChangeEmail(tester, repository);
      await fillForm(tester, email: '  New.Runner@example.com ');

      await tapSave(tester);

      verifyChanged(email: 'New.Runner@example.com');
      expect(find.byType(ChangeEmailPage), findsNothing);
      expect(find.text(parentText), findsOneWidget);
      expect(
        find.text('Email changed to new.runner@example.com'),
        findsOneWidget,
      );
    });

    testWidgets('goes back even when the save also refreshes the router, as '
        'the session update does', (tester) async {
      final refresh = ChangeNotifier();
      addTearDown(refresh.dispose);
      when(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          currentPassword: any(named: 'currentPassword'),
        ),
      ).thenAnswer((invocation) async {
        // `AuthBloc` handles the announced user a little later and emits it,
        // which refreshes the router.
        unawaited(Future<void>(refresh.notifyListeners));
        return testUser
            .copyWith(email: invocation.namedArguments[#newEmail] as String)
            .toEntity();
      });
      await pumpChangeEmail(tester, repository, refreshListenable: refresh);
      await fillForm(tester);

      await tapSave(tester);

      expect(find.byType(ChangeEmailPage), findsNothing);
      expect(find.text(parentText), findsOneWidget);
    });

    testWidgets('goes to the Profile tab when it is the only page', (
      tester,
    ) async {
      await pumpChangeEmail(tester, repository, pushed: false);
      expect(find.byType(BackButton), findsNothing);
      await fillForm(tester);

      await tapSave(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ChangeEmailPage), findsNothing);
      expect(find.text(parentText), findsOneWidget);
    });

    testWidgets('shows progress and locks the form while it saves', (
      tester,
    ) async {
      final pending = Completer<AuthUser>();
      when(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          currentPassword: any(named: 'currentPassword'),
        ),
      ).thenAnswer((_) => pending.future);
      await pumpChangeEmail(tester, repository);
      await fillForm(tester);

      await tester.tap(saveButton);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(isSaveEnabled(tester), isFalse);
      expect(tester.widget<TextField>(fieldFor(emailLabel)).enabled, isFalse);
      expect(
        tester.widget<TextField>(fieldFor(passwordLabel)).enabled,
        isFalse,
      );

      pending.complete(testUser.toEntity());
      await tester.pumpAndSettle();
    });
  });

  group('errors', () {
    testWidgets('incorrect_password shows under Current Password', (
      tester,
    ) async {
      failChangeEmail(
        repository,
        AuthFailure(AuthFailureCode.incorrectPassword),
      );
      await pumpChangeEmail(tester, repository);
      await fillForm(tester);

      await tapSave(tester);

      final error = find.text('The current password is incorrect.');
      expect(error, findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text(passwordLabel),
                matching: find.byType(Column),
              )
              .first,
          matching: error,
        ),
        findsOneWidget,
      );
      expect(find.byType(ChangeEmailPage), findsOneWidget);
    });

    testWidgets('email_taken shows under the email, and typing clears it', (
      tester,
    ) async {
      failChangeEmail(repository, AuthFailure(AuthFailureCode.emailTaken));
      await pumpChangeEmail(tester, repository);
      await fillForm(tester);

      await tapSave(tester);
      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );

      await tester.enterText(fieldFor(emailLabel), 'other@example.com');
      await tester.pumpAndSettle();
      expect(
        find.text('An account with this email already exists.'),
        findsNothing,
      );
    });

    testWidgets('a new_email 422 shows under the email', (tester) async {
      failChangeEmail(
        repository,
        AuthFailure(
          AuthFailureCode.validation,
          fieldErrors: const {'new_email': 'New email must differ.'},
        ),
      );
      await pumpChangeEmail(tester, repository);
      await fillForm(tester);

      await tapSave(tester);

      expect(find.text('New email must differ.'), findsOneWidget);
    });

    testWidgets('rate_limited is a banner with the wait time', (tester) async {
      failChangeEmail(
        repository,
        AuthFailure(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 14),
        ),
      );
      await pumpChangeEmail(tester, repository);
      await fillForm(tester);

      await tapSave(tester);

      expect(find.textContaining('Try again in 14 minutes.'), findsOneWidget);
      // Typing keeps what was typed and the banner goes away.
      await tester.enterText(fieldFor(passwordLabel), 'run4medals2');
      await tester.pumpAndSettle();
      expect(find.textContaining('Try again in 14 minutes.'), findsNothing);
    });

    testWidgets('a network failure is a banner and the form stays filled', (
      tester,
    ) async {
      failChangeEmail(repository, AuthFailure(AuthFailureCode.network));
      await pumpChangeEmail(tester, repository);
      await fillForm(tester);

      await tapSave(tester);

      expect(
        find.text('Cannot reach StrideQuest. Check your connection.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(fieldFor(emailLabel)).controller!.text,
        'new.runner@example.com',
      );
      expect(isSaveEnabled(tester), isTrue);
    });
  });

  group('states', () {
    late MockChangeEmailBloc bloc;

    setUp(() => bloc = MockChangeEmailBloc());

    Future<void> pumpState(
      WidgetTester tester,
      ChangeEmailState state, {
      bool settle = true,
    }) async {
      whenListen(
        bloc,
        const Stream<ChangeEmailState>.empty(),
        initialState: state,
      );
      await pumpScreen(
        tester,
        BlocProvider<ChangeEmailBloc>.value(
          value: bloc,
          child: const ChangeEmailPage(),
        ),
        settle: settle,
      );
    }

    testWidgets('loading shows a progress indicator', (tester) async {
      await pumpState(tester, const ChangeEmailLoading(), settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(emailLabel), findsNothing);
    });

    testWidgets('a load error shows the message and Try again reloads', (
      tester,
    ) async {
      await pumpState(
        tester,
        ChangeEmailLoadFailed(AuthFailure(AuthFailureCode.notAuthenticated)),
      );

      expect(find.text('Sign in to continue.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      verify(() => bloc.add(const ChangeEmailStarted())).called(1);
    });

    testWidgets('typing and Save send the bloc events', (tester) async {
      await pumpState(
        tester,
        ChangeEmailForm(
          currentEmail: testUser.email,
          newEmail: 'new.runner@example.com',
          password: 'run4medals',
        ),
      );

      await tester.enterText(fieldFor(emailLabel), 'a@b.co');
      await tester.enterText(fieldFor(passwordLabel), 'pw');
      await tester.tap(saveButton);

      verify(() => bloc.add(const ChangeEmailEmailChanged('a@b.co'))).called(1);
      verify(() => bloc.add(const ChangeEmailPasswordChanged('pw'))).called(1);
      verify(() => bloc.add(const ChangeEmailSubmitted())).called(1);
    });
  });

  group('layout and accessibility', () {
    for (final size in [smallPhone, largePhone]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('the form fits and is accessible on $size at text '
            'x$textScale', (tester) async {
          await pumpChangeEmail(
            tester,
            repository,
            size: size,
            textScale: textScale,
          );

          expectNoLayoutException(tester);
          await expectAccessible(tester);
        });

        testWidgets('the form with errors fits and is accessible on $size at '
            'text x$textScale', (tester) async {
          failChangeEmail(
            repository,
            AuthFailure(
              AuthFailureCode.validation,
              fieldErrors: const {
                'new_email': 'New email must differ from the current email.',
                'current_password': 'Enter your password.',
                'extra': 'Something else is wrong.',
              },
            ),
          );
          await pumpChangeEmail(
            tester,
            repository,
            size: size,
            textScale: textScale,
          );
          await fillForm(tester);
          await tapSave(tester);

          expect(find.text('Something else is wrong.'), findsOneWidget);
          expectNoLayoutException(tester);
          await expectAccessible(tester);
        });
      }
    }
  });
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/theme/app_theme.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_password_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/change_password_page.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/change_password_harness.dart';
import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/mock_auth_bloc.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = changePasswordRepository());

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(savePasswordButton);
    await tester.pumpAndSettle();
    await tester.tap(savePasswordButton);
    await tester.pumpAndSettle();
  }

  group('the form', () {
    testWidgets('shows the title, three fields, the hint and Save, no '
        'Forgot Password link', (tester) async {
      await pumpChangePassword(tester, repository);

      expect(find.widgetWithText(AppBar, 'Password'), findsOneWidget);
      expect(find.text(currentLabel), findsOneWidget);
      expect(find.text(newLabel), findsOneWidget);
      expect(find.text(confirmLabel), findsOneWidget);
      expect(
        find.text('At least 8 characters, with a letter and a digit'),
        findsOneWidget,
      );
      expect(find.text('Show'), findsNWidgets(3));
      expect(find.textContaining('Forgot'), findsNothing);
      expect(savePasswordButton, findsOneWidget);
    });

    testWidgets('Save is off until all three are filled, the new one is '
        'valid and Confirm matches', (tester) async {
      await pumpChangePassword(tester, repository);
      expect(isPasswordSaveEnabled(tester), isFalse);

      await fillPasswords(tester, current: '');
      expect(isPasswordSaveEnabled(tester), isFalse, reason: 'no current');

      await fillPasswords(tester, next: 'short1');
      expect(isPasswordSaveEnabled(tester), isFalse, reason: 'rule broken');
      expect(
        find.text(
          'Password must be 8 to 128 characters with a letter and a digit.',
        ),
        findsOneWidget,
      );

      await fillPasswords(tester, confirm: 'other5medals');
      expect(isPasswordSaveEnabled(tester), isFalse, reason: 'mismatch');
      expect(find.text('Passwords do not match.'), findsOneWidget);

      await fillPasswords(tester);
      expect(isPasswordSaveEnabled(tester), isTrue);
      expect(find.text('Passwords do not match.'), findsNothing);
    });

    testWidgets('each field has its own Show and Hide toggle', (tester) async {
      await pumpChangePassword(tester, repository);
      bool obscured(String label) =>
          tester.widget<TextField>(passwordFieldFor(label)).obscureText;

      await tester.tap(find.text('Show').at(1));
      await tester.pumpAndSettle();

      expect(obscured(currentLabel), isTrue);
      expect(obscured(newLabel), isFalse);
      expect(obscured(confirmLabel), isTrue);
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(obscured(newLabel), isTrue);
    });

    testWidgets('Next moves down the fields and Done saves', (tester) async {
      await pumpChangePassword(tester, repository);
      await fillPasswords(tester);
      await tester.tap(passwordFieldFor(currentLabel));
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(passwordHasFocus(tester, newLabel), isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(passwordHasFocus(tester, confirmLabel), isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(passwordHasFocus(tester, confirmLabel), isFalse);
      verify(
        () => repository.changePassword(
          currentPassword: 'run4medals',
          newPassword: 'newrun5medals',
        ),
      ).called(1);
    });

    testWidgets('Done with an incomplete form does not save', (tester) async {
      await pumpChangePassword(tester, repository);
      await tester.tap(passwordFieldFor(confirmLabel));
      await tester.enterText(passwordFieldFor(confirmLabel), 'newrun5medals');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verifyNever(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      );
    });
  });

  group('saving', () {
    testWidgets('sends both passwords, shows a message and goes back', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = smallPhone;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => changePasswordPage(repository),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await fillPasswords(tester);

      await tapSave(tester);

      verify(
        () => repository.changePassword(
          currentPassword: 'run4medals',
          newPassword: 'newrun5medals',
        ),
      ).called(1);
      expect(find.byType(ChangePasswordPage), findsNothing);
      expect(find.text('Password changed'), findsOneWidget);
    });

    testWidgets('shows progress and locks the form while it saves', (
      tester,
    ) async {
      final pending = Completer<void>();
      when(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) => pending.future);
      await pumpChangePassword(tester, repository);
      await fillPasswords(tester);

      await tester.tap(savePasswordButton);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(isPasswordSaveEnabled(tester), isFalse);
      for (final label in [currentLabel, newLabel, confirmLabel]) {
        expect(
          tester.widget<TextField>(passwordFieldFor(label)).enabled,
          false,
        );
      }

      pending.complete();
      await tester.pumpAndSettle();
    });
  });

  group('errors', () {
    testWidgets('incorrect_password shows under Current Password', (
      tester,
    ) async {
      failChangePassword(
        repository,
        AuthFailure(AuthFailureCode.incorrectPassword),
      );
      await pumpChangePassword(tester, repository);
      await fillPasswords(tester);

      await tapSave(tester);

      final error = find.text('The current password is incorrect.');
      expect(error, findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text(currentLabel),
                matching: find.byType(Column),
              )
              .first,
          matching: error,
        ),
        findsOneWidget,
      );
      expect(find.byType(ChangePasswordPage), findsOneWidget);

      // Typing in the field clears its own error.
      await tester.enterText(passwordFieldFor(currentLabel), 'run4medals2');
      await tester.pumpAndSettle();
      expect(error, findsNothing);
    });

    testWidgets('a new_password 422 shows under New Password', (tester) async {
      failChangePassword(
        repository,
        AuthFailure(
          AuthFailureCode.validation,
          fieldErrors: const {'new_password': 'New password must differ.'},
        ),
      );
      await pumpChangePassword(tester, repository);
      await fillPasswords(tester);

      await tapSave(tester);

      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text(newLabel), matching: find.byType(Column))
              .first,
          matching: find.text('New password must differ.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rate_limited is a banner with the wait time', (tester) async {
      failChangePassword(
        repository,
        AuthFailure(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 14),
        ),
      );
      await pumpChangePassword(tester, repository);
      await fillPasswords(tester);

      await tapSave(tester);

      expect(find.textContaining('Try again in 14 minutes.'), findsOneWidget);
      await tester.enterText(passwordFieldFor(currentLabel), 'run4medals2');
      await tester.pumpAndSettle();
      expect(find.textContaining('Try again in 14 minutes.'), findsNothing);
    });

    testWidgets('a network failure is a banner and the form stays filled', (
      tester,
    ) async {
      failChangePassword(repository, AuthFailure(AuthFailureCode.network));
      await pumpChangePassword(tester, repository);
      await fillPasswords(tester);

      await tapSave(tester);

      expect(
        find.text('Cannot reach StrideQuest. Check your connection.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(passwordFieldFor(newLabel)).controller!.text,
        'newrun5medals',
      );
      expect(isPasswordSaveEnabled(tester), isTrue);
    });
  });

  group('states', () {
    late MockChangePasswordBloc bloc;

    setUp(() => bloc = MockChangePasswordBloc());

    testWidgets('typing and Save send the bloc events', (tester) async {
      whenListen(
        bloc,
        const Stream<ChangePasswordState>.empty(),
        initialState: const ChangePasswordState(
          current: 'run4medals',
          newPassword: 'newrun5medals',
          confirm: 'newrun5medals',
        ),
      );
      await pumpScreen(
        tester,
        BlocProvider<ChangePasswordBloc>.value(
          value: bloc,
          child: const ChangePasswordPage(),
        ),
      );

      await tester.enterText(passwordFieldFor(currentLabel), 'a');
      await tester.enterText(passwordFieldFor(newLabel), 'b');
      await tester.enterText(passwordFieldFor(confirmLabel), 'c');
      await tester.tap(savePasswordButton);

      verify(() => bloc.add(const ChangePasswordCurrentChanged('a'))).called(1);
      verify(() => bloc.add(const ChangePasswordNewChanged('b'))).called(1);
      verify(() => bloc.add(const ChangePasswordConfirmChanged('c'))).called(1);
      verify(() => bloc.add(const ChangePasswordSubmitted())).called(1);
    });
  });

  group('layout and accessibility', () {
    for (final size in [smallPhone, largePhone]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('the form fits and is accessible on $size at text '
            'x$textScale', (tester) async {
          await pumpChangePassword(
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
          failChangePassword(
            repository,
            AuthFailure(
              AuthFailureCode.validation,
              fieldErrors: const {
                'new_password': 'New password must differ.',
                'current_password': 'Enter your password.',
                'extra': 'Something else is wrong.',
              },
            ),
          );
          await pumpChangePassword(
            tester,
            repository,
            size: size,
            textScale: textScale,
          );
          await fillPasswords(tester);
          await tapSave(tester);

          expect(find.text('Something else is wrong.'), findsOneWidget);
          expectNoLayoutException(tester);
          await expectAccessible(tester);
        });
      }
    }
  });
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/delete_account_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/delete_account_page.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/delete_account_harness.dart';
import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/mock_auth_bloc.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = deleteAccountRepository());

  Future<void> type(WidgetTester tester, [String text = 'run4medals']) async {
    await tester.enterText(deletePasswordField, text);
    await tester.pumpAndSettle();
  }

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
  }

  group('the form', () {
    testWidgets('shows the title, the copy, the field and the button', (
      tester,
    ) async {
      await pumpDeleteAccount(tester, repository);

      expect(find.widgetWithText(AppBar, 'Delete Account'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(
        find.text(
          'This permanently deletes your StrideQuest account: your profile, '
          'the challenges you joined, your runs, medals, and the steps and '
          'activity synced from Apple Health or Health Connect. '
          "This can't be undone.",
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your data in Apple Health or Health Connect stays on your phone. '
          'We only delete our copy.',
        ),
        findsOneWidget,
      );
      expect(find.text(deletePasswordLabel), findsOneWidget);
      expect(deleteButton, findsOneWidget);
    });

    testWidgets('the button is in the error color', (tester) async {
      await pumpDeleteAccount(tester, repository);

      final style = tester.widget<FilledButton>(deleteButton).style!;
      final colors = Theme.of(tester.element(deleteButton)).colorScheme;
      expect(style.backgroundColor!.resolve({}), colors.error);
    });

    testWidgets('the password is hidden, and Show reveals it', (tester) async {
      await pumpDeleteAccount(tester, repository);
      bool obscured() =>
          tester.widget<TextField>(deletePasswordField).obscureText;

      expect(obscured(), isTrue);
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(obscured(), isFalse);
    });

    testWidgets('the button is off while the password is empty', (
      tester,
    ) async {
      await pumpDeleteAccount(tester, repository);
      expect(isDeleteEnabled(tester), isFalse);

      await type(tester);
      expect(isDeleteEnabled(tester), isTrue);

      await type(tester, '');
      expect(isDeleteEnabled(tester), isFalse);
    });

    testWidgets('over 128 characters shows an error and blocks the button', (
      tester,
    ) async {
      await pumpDeleteAccount(tester, repository);
      await type(tester, 'a' * 129);

      expect(find.text('Passwords are up to 128 characters.'), findsOneWidget);
      expect(isDeleteEnabled(tester), isFalse);
      expect(
        tester.widget<TextField>(deletePasswordField).controller!.text.length,
        129,
      );

      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      verifyNever(
        () => repository.deleteAccount(
          currentPassword: any(named: 'currentPassword'),
        ),
      );

      await type(tester, 'a' * 128);
      expect(find.text('Passwords are up to 128 characters.'), findsNothing);
      expect(isDeleteEnabled(tester), isTrue);
    });

    testWidgets('the button sends the password as typed', (tester) async {
      await pumpDeleteAccount(tester, repository);
      await type(tester, ' run4medals ');

      await tapDelete(tester);

      verify(
        () => repository.deleteAccount(currentPassword: ' run4medals '),
      ).called(1);
    });

    testWidgets('Done on the keyboard deletes', (tester) async {
      await pumpDeleteAccount(tester, repository);
      await tester.tap(deletePasswordField);
      await type(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verify(
        () => repository.deleteAccount(currentPassword: 'run4medals'),
      ).called(1);
    });

    testWidgets('Done on an empty field does nothing', (tester) async {
      await pumpDeleteAccount(tester, repository);
      await tester.tap(deletePasswordField);
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verifyNever(
        () => repository.deleteAccount(
          currentPassword: any(named: 'currentPassword'),
        ),
      );
    });

    testWidgets('back returns without deleting', (tester) async {
      await pumpDeleteAccount(tester, repository);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text(parentText), findsOneWidget);
      verifyNever(
        () => repository.deleteAccount(
          currentPassword: any(named: 'currentPassword'),
        ),
      );
    });
  });

  group('submitting', () {
    testWidgets('shows a spinner in the button and locks the field', (
      tester,
    ) async {
      final completer = Completer<void>();
      when(
        () => repository.deleteAccount(currentPassword: 'run4medals'),
      ).thenAnswer((_) => completer.future);
      await pumpDeleteAccount(tester, repository);
      await type(tester);

      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('Delete account'), findsNothing);
      expect(isDeleteEnabled(tester), isFalse);
      expect(tester.widget<TextField>(deletePasswordField).enabled, isFalse);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('success leaves the page where it is (the router decides)', (
      tester,
    ) async {
      await pumpDeleteAccount(tester, repository);
      await type(tester);

      await tapDelete(tester);

      expect(find.byType(DeleteAccountPage), findsOneWidget);
      expect(find.text(parentText), findsNothing);
    });
  });

  group('errors', () {
    for (final (failure, message) in [
      (
        AuthFailure(AuthFailureCode.incorrectPassword),
        'The current password is incorrect.',
      ),
      (
        AuthFailure(AuthFailureCode.lastAdmin),
        "You're the only admin. Make another account an admin before "
            'deleting yours.',
      ),
      (
        AuthFailure(AuthFailureCode.network),
        'Cannot reach StrideQuest. Check your connection.',
      ),
      (
        AuthFailure(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 14),
        ),
        'Too many attempts. Wait a few minutes and try again. '
            'Try again in 14 minutes.',
      ),
      (
        AuthFailure(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(seconds: 30),
        ),
        'Too many attempts. Wait a few minutes and try again. '
            'Try again in 1 minute.',
      ),
    ]) {
      testWidgets('shows "$message" in a banner and allows a retry', (
        tester,
      ) async {
        failDeleteAccount(repository, failure);
        await pumpDeleteAccount(tester, repository);
        await type(tester);

        await tapDelete(tester);

        expect(find.text(message), findsOneWidget);
        expect(isDeleteEnabled(tester), isTrue);
        expect(tester.widget<TextField>(deletePasswordField).enabled, isTrue);
        expect(find.byType(DeleteAccountPage), findsOneWidget);
        await expectAccessible(tester);

        // Typing clears the banner.
        await type(tester, 'run4medals2');
        expect(find.text(message), findsNothing);
      });
    }
  });

  group('layout and accessibility', () {
    for (final size in [smallPhone, largePhone]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('fits and is accessible on $size at text x$textScale', (
          tester,
        ) async {
          failDeleteAccount(repository, AuthFailure(AuthFailureCode.lastAdmin));
          await pumpDeleteAccount(
            tester,
            repository,
            size: size,
            textScale: textScale,
          );
          expectNoLayoutException(tester);
          await expectAccessible(tester);

          await type(tester);
          await tapDelete(tester);

          expect(find.textContaining("You're the only admin"), findsOneWidget);
          expectNoLayoutException(tester);
          await expectAccessible(tester);
        });
      }
    }
  });

  testWidgets('renders every state of a mocked bloc', (tester) async {
    for (final state in [
      const DeleteAccountState(),
      const DeleteAccountState(
        password: 'x',
        status: DeleteAccountStatus.submitting,
      ),
      const DeleteAccountState(
        password: 'x',
        status: DeleteAccountStatus.success,
      ),
    ]) {
      final bloc = MockDeleteAccountBloc();
      whenListen(
        bloc,
        const Stream<DeleteAccountState>.empty(),
        initialState: state,
      );
      await pumpScreen(
        tester,
        BlocProvider<DeleteAccountBloc>.value(
          value: bloc,
          child: const DeleteAccountPage(),
        ),
        settle: false,
      );
      await tester.pump();
      expect(find.byType(DeleteAccountPage), findsOneWidget);
    }
  });
}

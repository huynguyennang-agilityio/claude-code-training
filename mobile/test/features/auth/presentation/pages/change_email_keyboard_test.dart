import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/change_email_harness.dart';
import '../../../../helpers/pump_screen.dart';

/// The Email form with the keyboard open (300 px of `viewInsets`).
const _keyboardHeight = 300.0;

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = changeEmailRepository());

  Future<void> pumpOpen(
    WidgetTester tester, {
    Size size = smallPhone,
    double textScale = 1,
  }) async {
    await pumpChangeEmail(tester, repository, size: size, textScale: textScale);
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
  }

  Future<void> focus(WidgetTester tester, String label) async {
    await tester.ensureVisible(fieldFor(label));
    await tester.pumpAndSettle();
    await tester.tap(fieldFor(label));
    await tester.pumpAndSettle();
  }

  void expectVisible(WidgetTester tester, Finder finder, Size size) {
    final rect = tester.getRect(finder);
    expect(
      rect.top,
      greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
    );
    expect(rect.bottom, lessThanOrEqualTo(size.height - _keyboardHeight));
  }

  for (final size in [smallPhone, largePhone]) {
    for (final textScale in [1.0, 2.0]) {
      group('with the keyboard open on $size at text x$textScale', () {
        testWidgets('does not overflow', (tester) async {
          await pumpOpen(tester, size: size, textScale: textScale);

          expectNoLayoutException(tester);
        });

        for (final (label, bad, error) in [
          (emailLabel, 'nope@', 'Enter a valid email address.'),
        ]) {
          testWidgets('keeps the focused $label and its error visible', (
            tester,
          ) async {
            await pumpOpen(tester, size: size, textScale: textScale);

            await focus(tester, label);
            await tester.enterText(fieldFor(label), bad);
            await tester.pumpAndSettle();

            expect(hasFocus(tester, label), isTrue);
            expectVisible(tester, fieldFor(label), size);
            expectVisible(tester, find.text(error), size);
            expectNoLayoutException(tester);
          });
        }

        testWidgets('keeps the focused password and its server error visible', (
          tester,
        ) async {
          failChangeEmail(
            repository,
            AuthFailure(AuthFailureCode.incorrectPassword),
          );
          await pumpOpen(tester, size: size, textScale: textScale);
          await fillForm(tester);
          await tester.ensureVisible(saveButton);
          await tester.pumpAndSettle();
          await tester.tap(saveButton);
          await tester.pumpAndSettle();

          await focus(tester, passwordLabel);

          expect(hasFocus(tester, passwordLabel), isTrue);
          expectVisible(tester, fieldFor(passwordLabel), size);
          expectVisible(
            tester,
            find.text('The current password is incorrect.'),
            size,
          );
        });

        testWidgets('lets the user scroll Save above the keyboard', (
          tester,
        ) async {
          await pumpOpen(tester, size: size, textScale: textScale);
          await fillForm(tester);

          await tester.ensureVisible(saveButton);
          await tester.pumpAndSettle();

          expectVisible(tester, saveButton, size);
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
          verify(
            () => repository.changeEmail(
              newEmail: 'new.runner@example.com',
              currentPassword: 'run4medals',
            ),
          ).called(1);
        });

        testWidgets('dragging the form up closes the keyboard', (tester) async {
          await pumpOpen(tester, size: size, textScale: textScale);
          await focus(tester, emailLabel);
          expect(hasFocus(tester, emailLabel), isTrue);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -80),
          );
          await tester.pumpAndSettle();

          expect(hasFocus(tester, emailLabel), isFalse);
        });

        testWidgets('tapping outside a field closes the keyboard', (
          tester,
        ) async {
          await pumpOpen(tester, size: size, textScale: textScale);
          await focus(tester, emailLabel);
          expect(hasFocus(tester, emailLabel), isTrue);

          await tester.tapAt(const Offset(2, 200));
          await tester.pumpAndSettle();

          expect(hasFocus(tester, emailLabel), isFalse);
        });
      });
    }
  }

  group('Next and Done', () {
    testWidgets('Next goes from the email to the password', (tester) async {
      await pumpOpen(tester);
      await focus(tester, emailLabel);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      expect(hasFocus(tester, passwordLabel), isTrue);
    });

    testWidgets('Done closes the keyboard and saves a valid form', (
      tester,
    ) async {
      await pumpOpen(tester);
      await fillForm(tester);
      await focus(tester, passwordLabel);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // The save pops the page, which takes the keyboard focus with it.
      expect(find.text(parentText), findsOneWidget);
      verify(
        () => repository.changeEmail(
          newEmail: 'new.runner@example.com',
          currentPassword: 'run4medals',
        ),
      ).called(1);
    });

    testWidgets('Done on an incomplete form closes the keyboard, no save', (
      tester,
    ) async {
      await pumpOpen(tester);
      await focus(tester, passwordLabel);
      await tester.enterText(fieldFor(passwordLabel), 'run4medals');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(hasFocus(tester, passwordLabel), isFalse);
      verifyNever(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          currentPassword: any(named: 'currentPassword'),
        ),
      );
    });
  });
}

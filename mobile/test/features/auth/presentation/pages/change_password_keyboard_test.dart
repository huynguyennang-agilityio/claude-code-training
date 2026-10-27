import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/change_password_harness.dart';
import '../../../../helpers/pump_screen.dart';

/// The Password form with the keyboard open (300 px of `viewInsets`).
const _keyboardHeight = 300.0;

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = changePasswordRepository());

  Future<void> pumpOpen(
    WidgetTester tester, {
    Size size = smallPhone,
    double textScale = 1,
  }) async {
    await pumpChangePassword(
      tester,
      repository,
      size: size,
      textScale: textScale,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
  }

  Future<void> focus(WidgetTester tester, String label) async {
    await tester.ensureVisible(passwordFieldFor(label));
    await tester.pumpAndSettle();
    await tester.tap(passwordFieldFor(label));
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

        for (final (label, errorText) in [
          (newLabel, null),
          (confirmLabel, 'Passwords do not match.'),
        ]) {
          testWidgets('keeps the focused $label and its error visible', (
            tester,
          ) async {
            await pumpOpen(tester, size: size, textScale: textScale);

            await focus(tester, label);
            await tester.enterText(
              passwordFieldFor(newLabel),
              errorText == null ? 'short1' : 'newrun5medals',
            );
            if (errorText != null) {
              await focus(tester, label);
              await tester.enterText(passwordFieldFor(label), 'different1');
            }
            await tester.pumpAndSettle();

            expect(passwordHasFocus(tester, label), isTrue);
            expectVisible(tester, passwordFieldFor(label), size);
            expectVisible(
              tester,
              find.text(
                errorText ??
                    'Password must be 8 to 128 characters with a letter and a '
                        'digit.',
              ),
              size,
            );
            expectNoLayoutException(tester);
          });
        }

        testWidgets('keeps the focused current password and its server '
            'error visible', (tester) async {
          failChangePassword(
            repository,
            AuthFailure(AuthFailureCode.incorrectPassword),
          );
          await pumpOpen(tester, size: size, textScale: textScale);
          await fillPasswords(tester);
          await tester.ensureVisible(savePasswordButton);
          await tester.pumpAndSettle();
          await tester.tap(savePasswordButton);
          await tester.pumpAndSettle();

          await focus(tester, currentLabel);

          expect(passwordHasFocus(tester, currentLabel), isTrue);
          expectVisible(tester, passwordFieldFor(currentLabel), size);
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
          await fillPasswords(tester);

          await tester.ensureVisible(savePasswordButton);
          await tester.pumpAndSettle();

          expectVisible(tester, savePasswordButton, size);
          await tester.tap(savePasswordButton);
          await tester.pumpAndSettle();
          verify(
            () => repository.changePassword(
              currentPassword: 'run4medals',
              newPassword: 'newrun5medals',
            ),
          ).called(1);
        });

        testWidgets('dragging the form up closes the keyboard', (tester) async {
          await pumpOpen(tester, size: size, textScale: textScale);
          await focus(tester, currentLabel);
          expect(passwordHasFocus(tester, currentLabel), isTrue);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -80),
          );
          await tester.pumpAndSettle();

          expect(passwordHasFocus(tester, currentLabel), isFalse);
        });

        testWidgets('tapping outside a field closes the keyboard', (
          tester,
        ) async {
          await pumpOpen(tester, size: size, textScale: textScale);
          await focus(tester, currentLabel);
          expect(passwordHasFocus(tester, currentLabel), isTrue);

          await tester.tapAt(const Offset(2, 200));
          await tester.pumpAndSettle();

          expect(passwordHasFocus(tester, currentLabel), isFalse);
        });
      });
    }
  }

  group('Next and Done', () {
    testWidgets('Next goes from field to field', (tester) async {
      await pumpOpen(tester);
      await focus(tester, currentLabel);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(passwordHasFocus(tester, newLabel), isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(passwordHasFocus(tester, confirmLabel), isTrue);
    });

    testWidgets('Done closes the keyboard and saves a valid form', (
      tester,
    ) async {
      await pumpOpen(tester);
      await fillPasswords(tester);
      await focus(tester, confirmLabel);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // The save pops the page, which takes the keyboard focus with it.
      expect(find.text(parentText), findsOneWidget);
      verify(
        () => repository.changePassword(
          currentPassword: 'run4medals',
          newPassword: 'newrun5medals',
        ),
      ).called(1);
    });

    testWidgets('Done on an incomplete form closes the keyboard, no save', (
      tester,
    ) async {
      await pumpOpen(tester);
      await focus(tester, confirmLabel);
      await tester.enterText(passwordFieldFor(confirmLabel), 'newrun5medals');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(passwordHasFocus(tester, confirmLabel), isFalse);
      verifyNever(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      );
    });
  });
}

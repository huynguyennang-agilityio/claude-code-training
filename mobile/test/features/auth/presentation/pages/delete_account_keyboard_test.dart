import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/delete_account_harness.dart';
import '../../../../helpers/pump_screen.dart';

/// The Delete Account form with the keyboard open (300 px of `viewInsets`).
const _keyboardHeight = 300.0;

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = deleteAccountRepository());

  Future<void> pumpOpen(
    WidgetTester tester, {
    Size size = smallPhone,
    double textScale = 1,
  }) async {
    await pumpDeleteAccount(
      tester,
      repository,
      size: size,
      textScale: textScale,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
    addTearDown(tester.view.resetViewInsets);
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
        testWidgets('keeps the focused field visible and does not overflow', (
          tester,
        ) async {
          await pumpOpen(tester, size: size, textScale: textScale);

          await tester.ensureVisible(deletePasswordField);
          await tester.pumpAndSettle();
          await tester.tap(deletePasswordField);
          await tester.pumpAndSettle();

          expectVisible(tester, deletePasswordField, size);
          expectNoLayoutException(tester);
        });

        testWidgets('lets the user scroll the button above the keyboard', (
          tester,
        ) async {
          await pumpOpen(tester, size: size, textScale: textScale);
          await tester.enterText(deletePasswordField, 'run4medals');

          await tester.ensureVisible(deleteButton);
          await tester.pumpAndSettle();

          expectVisible(tester, deleteButton, size);
          await tester.tap(deleteButton);
          await tester.pumpAndSettle();
          verify(
            () => repository.deleteAccount(currentPassword: 'run4medals'),
          ).called(1);
        });

        testWidgets('keeps the field and the error banner visible', (
          tester,
        ) async {
          failDeleteAccount(
            repository,
            AuthFailure(AuthFailureCode.incorrectPassword),
          );
          await pumpOpen(tester, size: size, textScale: textScale);
          await tester.enterText(deletePasswordField, 'run4medals');
          await tester.ensureVisible(deleteButton);
          await tester.pumpAndSettle();
          await tester.tap(deleteButton);
          await tester.pumpAndSettle();

          await tester.ensureVisible(deletePasswordField);
          await tester.pumpAndSettle();
          await tester.tap(deletePasswordField);
          await tester.pumpAndSettle();

          expectVisible(tester, deletePasswordField, size);
          expectNoLayoutException(tester);
        });

        testWidgets('tapping outside the field closes the keyboard', (
          tester,
        ) async {
          await pumpOpen(tester, size: size, textScale: textScale);
          await tester.ensureVisible(deletePasswordField);
          await tester.pumpAndSettle();
          await tester.tap(deletePasswordField);
          await tester.pumpAndSettle();
          bool focused() => tester
              .widget<EditableText>(
                find.descendant(
                  of: deletePasswordField,
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus;
          expect(focused(), isTrue);

          await tester.tapAt(const Offset(2, 200));
          await tester.pumpAndSettle();

          expect(focused(), isFalse);
        });
      });
    }
  }
}

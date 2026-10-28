import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/profile_fixtures.dart';
import '../../../../helpers/profile_info_harness.dart';
import '../../../../helpers/pump_screen.dart';

/// The Profile info form with the keyboard open (300 px of `viewInsets`).
const _keyboardHeight = 300.0;

void main() {
  late MockProfileRepository repository;

  setUpAll(registerProfileFallback);
  setUp(() => repository = repositoryWith(sampleProfile));

  Future<void> pumpOpen(
    WidgetTester tester, {
    Size size = smallPhone,
    double textScale = 1,
  }) async {
    await pumpProfileInfo(tester, repository, size: size, textScale: textScale);
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

  double visibleBottom(Size size) => size.height - _keyboardHeight;

  double appBarBottom(WidgetTester tester) =>
      tester.getRect(find.byType(AppBar)).bottom;

  void expectVisible(WidgetTester tester, Finder finder, Size size) {
    final rect = tester.getRect(finder);
    expect(rect.top, greaterThanOrEqualTo(appBarBottom(tester)));
    expect(rect.bottom, lessThanOrEqualTo(visibleBottom(size)));
  }

  for (final size in [smallPhone, largePhone]) {
    for (final textScale in [1.0, 2.0]) {
      group('with the keyboard open on $size at text x$textScale', () {
        testWidgets('does not overflow', (tester) async {
          await pumpOpen(tester, size: size, textScale: textScale);

          expectNoLayoutException(tester);
        });

        for (final (label, bad, error) in [
          ('First Name', 'x' * 51, 'First name is at most 50 characters.'),
          ('State', 'x' * 101, 'State is at most 100 characters.'),
          ('Weight', '10', 'Weight must be between 44.1 and 881.8 lbs.'),
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

        testWidgets('keeps the height error visible under the focused field', (
          tester,
        ) async {
          await pumpOpen(tester, size: size, textScale: textScale);

          await focus(tester, 'Height (in)');
          await tester.enterText(fieldFor('Height (in)'), '12');
          await tester.pumpAndSettle();

          expectVisible(tester, fieldFor('Height (in)'), size);
          expectVisible(
            tester,
            find.text('Enter feet, and inches under 12.'),
            size,
          );
        });

        testWidgets('lets the user scroll Save above the keyboard', (
          tester,
        ) async {
          await pumpOpen(tester, size: size, textScale: textScale);

          await tester.ensureVisible(find.text('Save'));
          await tester.pumpAndSettle();

          expectVisible(tester, find.byType(OutlinedButton), size);
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          verify(() => repository.saveProfile(any())).called(1);
        });

        testWidgets('dragging the form up closes the keyboard', (tester) async {
          await pumpOpen(tester, size: size, textScale: textScale);
          await focus(tester, 'First Name');
          expect(hasFocus(tester, 'First Name'), isTrue);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -80),
          );
          await tester.pumpAndSettle();

          expect(hasFocus(tester, 'First Name'), isFalse);
        });

        testWidgets(
          'dragging down at the top of the form closes the keyboard (Android)',
          (tester) async {
            expect(defaultTargetPlatform, TargetPlatform.android);
            await pumpOpen(tester, size: size, textScale: textScale);
            await focus(tester, 'First Name');
            expect(hasFocus(tester, 'First Name'), isTrue);
            final top = tester.getTopLeft(find.byType(CustomScrollView));

            await tester.dragFrom(
              top + const Offset(60, 300),
              const Offset(0, 120),
            );
            await tester.pumpAndSettle();

            expect(hasFocus(tester, 'First Name'), isFalse);
          },
        );

        testWidgets('tapping outside a field closes the keyboard', (
          tester,
        ) async {
          await pumpOpen(tester, size: size, textScale: textScale);
          await focus(tester, 'First Name');
          expect(hasFocus(tester, 'First Name'), isTrue);

          await tester.tapAt(const Offset(2, 200));
          await tester.pumpAndSettle();

          expect(hasFocus(tester, 'First Name'), isFalse);
        });
      });
    }
  }

  group('Next and Done', () {
    testWidgets('Next walks the text fields in order, past the pickers', (
      tester,
    ) async {
      await pumpOpen(tester);
      await focus(tester, 'First Name');

      for (final label in [
        'Last Name',
        'State',
        'Height (ft)',
        'Height (in)',
        'Weight',
      ]) {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        expect(hasFocus(tester, label), isTrue, reason: 'focus on $label');
      }
    });

    testWidgets('Done on Weight closes the keyboard and saves', (tester) async {
      await pumpOpen(tester);
      await focus(tester, 'Weight');
      await tester.enterText(fieldFor('Weight'), '190');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(hasFocus(tester, 'Weight'), isFalse);
      expect(savedProfile(repository).weightKg, 86.2);
    });

    testWidgets('Done on an invalid Weight closes the keyboard, no save', (
      tester,
    ) async {
      await pumpOpen(tester);
      await focus(tester, 'Weight');
      await tester.enterText(fieldFor('Weight'), 'abc');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(hasFocus(tester, 'Weight'), isFalse);
      expect(find.text('Enter the weight as a number.'), findsOneWidget);
      verifyNever(() => repository.saveProfile(any()));
    });
  });

  group('each picker closes the keyboard first', () {
    for (final (label, sheet) in [
      ('Birthday', find.byType(DatePickerDialog)),
      ('Country', find.byType(BottomSheet)),
      ('Gender', find.byType(BottomSheet)),
    ]) {
      testWidgets(label, (tester) async {
        await pumpOpen(tester);
        await focus(tester, 'First Name');
        expect(hasFocus(tester, 'First Name'), isTrue);

        await tester.ensureVisible(pickerFor(label));
        await tester.pumpAndSettle();
        await tester.tap(pickerFor(label));
        await tester.pump();

        expect(hasFocus(tester, 'First Name'), isFalse);
        await tester.pumpAndSettle();
        expect(sheet, findsOneWidget);
      });
    }
  });
}

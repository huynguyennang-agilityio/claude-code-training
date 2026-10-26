import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/shared/widgets/settings_form_layout.dart';

import '../../helpers/expect_accessible.dart';
import '../../helpers/pump_screen.dart';

const _keyboardHeight = 300.0;
const _lastField = Key('last');
const _save = Key('save');

/// Several fields, an error line under the last one, and Save.
class _SampleForm extends StatelessWidget {
  const _SampleForm({required this.focusNodes, this.onBack});

  final List<FocusNode> focusNodes;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SettingsFormLayout(
      title: 'Sample',
      onBack: onBack,
      actions: [
        FilledButton(key: _save, onPressed: () {}, child: const Text('Save')),
      ],
      children: [
        for (var i = 0; i < focusNodes.length; i++) ...[
          TextField(
            key: i == focusNodes.length - 1 ? _lastField : Key('field$i'),
            focusNode: focusNodes[i],
            scrollPadding: SettingsFormLayout.scrollPadding,
            decoration: InputDecoration(
              labelText: 'Field $i',
              errorText: i == focusNodes.length - 1 ? 'Last field error' : null,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

void main() {
  late List<FocusNode> nodes;

  setUp(() => nodes = List.generate(6, (_) => FocusNode()));
  tearDown(() {
    for (final n in nodes) {
      n.dispose();
    }
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    Size size = smallPhone,
    double textScale = 1,
    VoidCallback? onBack,
  }) => pumpScreen(
    tester,
    _SampleForm(focusNodes: nodes, onBack: onBack),
    size: size,
    textScale: textScale,
  );

  Future<void> openKeyboard(WidgetTester tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
  }

  double visibleBottom(Size size) => size.height - _keyboardHeight;

  double appBarBottom(WidgetTester tester) =>
      tester.getRect(find.byType(AppBar)).bottom;

  testWidgets('shows the title, a back button, the fields and Save', (
    tester,
  ) async {
    var back = 0;
    await pumpForm(tester, onBack: () => back++);

    expect(find.text('Sample'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    expect(back, 1);
  });

  for (final size in [smallPhone, largePhone]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('fits and is accessible on $size at text x$textScale', (
        tester,
      ) async {
        await pumpForm(tester, size: size, textScale: textScale);

        expectNoLayoutException(tester);
        await expectAccessible(tester);
      });
    }
  }

  for (final size in [smallPhone, largePhone]) {
    for (final textScale in [1.0, 2.0]) {
      group('with the keyboard open on $size at text x$textScale', () {
        testWidgets('does not overflow', (tester) async {
          await pumpForm(tester, size: size, textScale: textScale);
          await openKeyboard(tester);

          expectNoLayoutException(tester);
        });

        testWidgets('keeps the focused last field and its error visible', (
          tester,
        ) async {
          await pumpForm(tester, size: size, textScale: textScale);
          await openKeyboard(tester);

          nodes.last.requestFocus();
          await tester.pumpAndSettle();

          expect(nodes.last.hasFocus, isTrue);
          final field = tester.getRect(find.byKey(_lastField));
          final error = tester.getRect(find.text('Last field error'));
          expect(field.top, greaterThanOrEqualTo(appBarBottom(tester)));
          expect(field.bottom, lessThanOrEqualTo(visibleBottom(size)));
          expect(error.bottom, lessThanOrEqualTo(visibleBottom(size)));
          expectNoLayoutException(tester);
        });

        testWidgets('lets the user scroll Save above the keyboard', (
          tester,
        ) async {
          await pumpForm(tester, size: size, textScale: textScale);
          await openKeyboard(tester);

          await tester.ensureVisible(find.byKey(_save));
          await tester.pumpAndSettle();

          final save = tester.getRect(find.byKey(_save));
          expect(save.bottom, lessThanOrEqualTo(visibleBottom(size)));
          expect(save.top, greaterThanOrEqualTo(appBarBottom(tester)));
        });

        testWidgets('dragging the form closes the keyboard', (tester) async {
          await pumpForm(tester, size: size, textScale: textScale);
          await openKeyboard(tester);
          nodes.first.requestFocus();
          await tester.pumpAndSettle();
          expect(nodes.first.hasFocus, isTrue);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -80),
          );
          await tester.pumpAndSettle();

          expect(nodes.first.hasFocus, isFalse);
        });

        testWidgets(
          'dragging down at the top of the form closes the keyboard',
          (tester) async {
            await pumpForm(tester, size: size, textScale: textScale);
            await openKeyboard(tester);
            nodes.first.requestFocus();
            await tester.pumpAndSettle();
            expect(nodes.first.hasFocus, isTrue);

            await tester.dragFrom(const Offset(200, 300), const Offset(0, 120));
            await tester.pumpAndSettle();

            expect(nodes.first.hasFocus, isFalse);
          },
        );

        testWidgets('tapping outside a field closes the keyboard', (
          tester,
        ) async {
          await pumpForm(tester, size: size, textScale: textScale);
          await openKeyboard(tester);
          nodes.first.requestFocus();
          await tester.pumpAndSettle();
          expect(nodes.first.hasFocus, isTrue);

          await tester.tapAt(const Offset(2, 200));
          await tester.pumpAndSettle();

          expect(nodes.first.hasFocus, isFalse);
        });
      });
    }
  }

  testWidgets(
    'dragging a short form that does not scroll closes the keyboard',
    (tester) async {
      for (final n in nodes) {
        n.dispose();
      }
      nodes = List.generate(2, (_) => FocusNode());
      expect(defaultTargetPlatform, TargetPlatform.android);
      await pumpForm(tester, size: largePhone);
      await openKeyboard(tester);
      nodes.last.requestFocus();
      await tester.pumpAndSettle();
      expect(nodes.last.hasFocus, isTrue);

      await tester.dragFrom(const Offset(200, 500), const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(nodes.last.hasFocus, isFalse);
    },
  );
}

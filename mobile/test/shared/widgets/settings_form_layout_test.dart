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

  double visibleBottom() => smallPhone.height - _keyboardHeight;

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

  for (final textScale in [1.0, 2.0]) {
    group('with the keyboard open at text x$textScale', () {
      testWidgets('does not overflow', (tester) async {
        await pumpForm(tester, textScale: textScale);
        await openKeyboard(tester);

        expectNoLayoutException(tester);
      });

      testWidgets('keeps the focused last field and its error visible', (
        tester,
      ) async {
        await pumpForm(tester, textScale: textScale);
        await openKeyboard(tester);

        nodes.last.requestFocus();
        await tester.pumpAndSettle();

        expect(nodes.last.hasFocus, isTrue);
        final field = tester.getRect(find.byKey(_lastField));
        final error = tester.getRect(find.text('Last field error'));
        expect(field.top, greaterThanOrEqualTo(0));
        expect(field.bottom, lessThanOrEqualTo(visibleBottom()));
        expect(error.bottom, lessThanOrEqualTo(visibleBottom()));
        expectNoLayoutException(tester);
      });

      testWidgets('lets the user scroll Save above the keyboard', (
        tester,
      ) async {
        await pumpForm(tester, textScale: textScale);
        await openKeyboard(tester);

        await tester.ensureVisible(find.byKey(_save));
        await tester.pumpAndSettle();

        final save = tester.getRect(find.byKey(_save));
        expect(save.bottom, lessThanOrEqualTo(visibleBottom()));
        expect(save.top, greaterThanOrEqualTo(0));
      });

      testWidgets('dragging the form closes the keyboard', (tester) async {
        await pumpForm(tester, textScale: textScale);
        await openKeyboard(tester);
        nodes.first.requestFocus();
        await tester.pumpAndSettle();
        expect(nodes.first.hasFocus, isTrue);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -80));
        await tester.pumpAndSettle();

        expect(nodes.first.hasFocus, isFalse);
      });

      testWidgets('tapping outside a field closes the keyboard', (
        tester,
      ) async {
        await pumpForm(tester, textScale: textScale);
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

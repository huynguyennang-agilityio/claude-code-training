import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/challenges/presentation/widgets/markdown_text.dart';

import '../../../../helpers/pump_screen.dart';

String _plain(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((text) => text.text.toPlainText())
    .join('\n');

void main() {
  testWidgets('paragraphs, bullets and bold render as text', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(
        body: MarkdownText(
          '# Rules\n\nWalk **50,000 steps**\nin October.\n\n- first\n- second',
        ),
      ),
    );

    final text = _plain(tester);
    expect(text, contains('Rules'));
    expect(text, contains('Walk 50,000 steps in October.'));
    expect(text, contains('first'));
    expect(text, contains('second'));
    expect(find.text('•  '), findsNWidgets(2));
  });

  testWidgets('HTML stays literal text and a link shows only its label', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const Scaffold(
        body: MarkdownText(
          '<script>alert(1)</script> <b>bold</b> [site](https://evil.example)',
        ),
      ),
    );

    final text = _plain(tester);
    expect(text, contains('<script>alert(1)</script>'));
    expect(text, contains('<b>bold</b>'));
    expect(text, contains('site'));
    expect(text, isNot(contains('evil.example')));
  });

  test('bold and italic become styled spans', () {
    final spans = MarkdownText.spans('a **b** *c* d', const TextStyle());

    expect(spans.map((s) => (s as TextSpan).text), ['a ', 'b', ' ', 'c', ' d']);
    expect((spans[1] as TextSpan).style?.fontWeight, FontWeight.w700);
    expect((spans[3] as TextSpan).style?.fontStyle, FontStyle.italic);
  });
}

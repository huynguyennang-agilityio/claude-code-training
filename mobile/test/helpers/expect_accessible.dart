import 'package:flutter_test/flutter_test.dart';

/// Checks the pumped screen against Flutter's accessibility guidelines:
/// tap targets on Android (48 dp) and iOS (44 pt), a label on every tappable
/// element, and text contrast.
Future<void> expectAccessible(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  } finally {
    semantics.dispose();
  }
}

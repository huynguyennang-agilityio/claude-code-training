import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the Profile tab of the bottom bar.
Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Profile'),
    ),
  );
  await tester.pumpAndSettle();
}

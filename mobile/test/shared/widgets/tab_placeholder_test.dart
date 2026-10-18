import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/challenges/presentation/pages/active_challenges_page.dart';
import 'package:stridequest/features/medals/presentation/pages/medals_page.dart';
import 'package:stridequest/shared/widgets/tab_placeholder.dart';

import '../../helpers/expect_accessible.dart';
import '../../helpers/pump_screen.dart';

void main() {
  testWidgets('shows the title and the message', (tester) async {
    await pumpScreen(
      tester,
      const TabPlaceholder(title: 'Things', message: 'Things show up here.'),
    );

    expect(find.text('Things'), findsOneWidget);
    expect(find.text('Things show up here.'), findsOneWidget);
  });

  group('the placeholder tabs', () {
    final tabs = <String, (Widget, String)>{
      'Active': (const ActiveChallengesPage(), '/active'),
      'Medals': (const MedalsPage(), '/medals'),
    };
    for (final entry in tabs.entries) {
      final (page, path) = entry.value;
      for (final size in [smallPhone, largePhone]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '${entry.key} ($path) fits and is accessible on $size at text '
            'x$textScale',
            (tester) async {
              await pumpScreen(tester, page, size: size, textScale: textScale);

              expect(find.text(entry.key), findsOneWidget);
              expectNoLayoutException(tester);
              await expectAccessible(tester);
            },
          );
        }
      }
    }
  });
}

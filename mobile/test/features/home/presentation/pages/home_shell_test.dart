import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/core/theme/app_tokens.dart';
import 'package:stridequest/features/home/presentation/pages/home_shell.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    int selected = 0,
    ValueChanged<int>? onSelected,
    Size size = smallPhone,
    double textScale = 1,
  }) {
    return pumpScreen(
      tester,
      HomeScaffold(
        body: const Center(child: Text('Body')),
        selectedIndex: selected,
        onSelected: onSelected ?? (_) {},
      ),
      size: size,
      textScale: textScale,
    );
  }

  testWidgets('shows the four tabs in order, with the body above them', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(find.text('Body'), findsOneWidget);
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label);
    expect(labels, ['Challenges', 'Active', 'Medals', 'Profile']);
  });

  testWidgets('the selected tab is the one given', (tester) async {
    await pumpBar(tester, selected: 2);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    final tapped = <int>[];
    await pumpBar(tester, onSelected: tapped.add);

    await tester.tap(find.text('Medals'));
    await tester.tap(find.text('Profile'));

    expect(tapped, [2, 3]);
  });

  testWidgets('each tab is a tap target of at least 48 high', (tester) async {
    await pumpBar(tester);

    for (final tab in HomeShell.tabs) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(tab.label),
          matching: find.byType(NavigationDestination),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(AppSizes.minTapTarget));
    }
  });

  group('layout and accessibility', () {
    for (var selected = 0; selected < HomeShell.tabs.length; selected++) {
      for (final size in [smallPhone, largePhone]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '${HomeShell.tabs[selected].label} selected fits and is accessible '
            'on $size at text x$textScale',
            (tester) async {
              await pumpBar(
                tester,
                selected: selected,
                size: size,
                textScale: textScale,
              );

              expectNoLayoutException(tester);
              await expectAccessible(tester);
            },
          );
        }
      }
    }
  });
}

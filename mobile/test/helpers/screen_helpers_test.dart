import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expect_accessible.dart';
import 'pump_screen.dart';

void main() {
  group('pumpScreen', () {
    testWidgets('uses the given screen size', (tester) async {
      late Size seen;
      await pumpScreen(
        tester,
        Builder(
          builder: (context) {
            seen = MediaQuery.sizeOf(context);
            return const SizedBox();
          },
        ),
        size: largePhone,
      );

      expect(seen, largePhone);
    });

    testWidgets('scales text', (tester) async {
      late TextScaler scaler;
      await pumpScreen(
        tester,
        Builder(
          builder: (context) {
            scaler = MediaQuery.textScalerOf(context);
            return const SizedBox();
          },
        ),
        textScale: 2,
      );

      expect(scaler.scale(10), 20);
    });

    testWidgets('can pump a screen that never settles', (tester) async {
      await pumpScreen(
        tester,
        const Center(child: CircularProgressIndicator()),
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('applies the app theme', (tester) async {
      late ThemeData theme;
      await pumpScreen(
        tester,
        Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(theme.useMaterial3, isTrue);
    });
  });

  group('expectNoLayoutException', () {
    testWidgets('fails on an overflow', (tester) async {
      await pumpScreen(
        tester,
        const Row(children: [SizedBox(width: 500, height: 10)]),
      );

      expect(() => expectNoLayoutException(tester), throwsA(anything));
    });
  });

  group('expectAccessible', () {
    testWidgets('passes for a normal button', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('Start')),
          ),
        ),
      );

      await expectAccessible(tester);
    });

    testWidgets('fails for a tap target that is too small', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child: Semantics(
              button: true,
              label: 'Tiny',
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(width: 16, height: 16),
              ),
            ),
          ),
        ),
      );

      await expectLater(expectAccessible(tester), throwsA(isA<TestFailure>()));
    });

    testWidgets('fails for a tappable element without a label', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child: Semantics(
              button: true,
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(width: 64, height: 64),
              ),
            ),
          ),
        ),
      );

      await expectLater(expectAccessible(tester), throwsA(isA<TestFailure>()));
    });
  });
}

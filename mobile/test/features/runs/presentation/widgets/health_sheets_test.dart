import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_gate_view.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_sheets.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/pump_screen.dart';

/// A page with one button that opens a sheet and records what it returned.
class _Opener extends StatelessWidget {
  const _Opener(this.open);

  final Future<void> Function(BuildContext) open;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => open(context),
        child: const Text('go'),
      ),
    ),
  );
}

void main() {
  group('HealthExplainerSheet', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('shows why, the four metrics and both buttons x$scale', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          const Scaffold(
            body: SingleChildScrollView(child: HealthExplainerSheet()),
          ),
          textScale: scale,
        );
        for (final metric in HealthMetric.values) {
          expect(find.text(metric.label), findsOneWidget);
        }
        expect(find.text('Required'), findsOneWidget);
        expect(find.text('Optional'), findsNWidgets(3));
        expect(find.text(healthConsentNote), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Not now'), findsOneWidget);
        expectNoLayoutException(tester);
        await expectAccessible(tester);
      });
    }

    testWidgets('Continue completes true and calls onContinue after closing', (
      tester,
    ) async {
      bool? result;
      var calls = 0;
      await pumpScreen(
        tester,
        _Opener((context) async {
          result = await showHealthExplainer(
            context,
            onContinue: () => calls++,
          );
        }),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(calls, 1);
      expect(find.byType(HealthExplainerSheet), findsNothing);
    });

    testWidgets('Not now completes false and does not call onContinue', (
      tester,
    ) async {
      bool? result;
      var calls = 0;
      await pumpScreen(
        tester,
        _Opener((context) async {
          result = await showHealthExplainer(
            context,
            onContinue: () => calls++,
          );
        }),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(calls, 0);
    });

    testWidgets('dismissing completes false', (tester) async {
      bool? result;
      await pumpScreen(
        tester,
        _Opener((context) async {
          result = await showHealthExplainer(context);
        }),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('HealthSettingsSheet', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('offers Open settings x$scale', (tester) async {
        await pumpScreen(
          tester,
          const Scaffold(
            body: SingleChildScrollView(child: HealthSettingsSheet()),
          ),
          textScale: scale,
        );
        expect(find.text('Open settings'), findsOneWidget);
        expectNoLayoutException(tester);
        await expectAccessible(tester);
      });
    }

    testWidgets('Open settings completes true and calls the callback', (
      tester,
    ) async {
      bool? result;
      var calls = 0;
      await pumpScreen(
        tester,
        _Opener((context) async {
          result = await showHealthSettings(
            context,
            onOpenSettings: () => calls++,
          );
        }),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(calls, 1);
    });
  });
}

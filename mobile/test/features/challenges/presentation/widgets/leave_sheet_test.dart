import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/presentation/widgets/leave_sheet.dart';

import '../../../../helpers/challenge_fixtures.dart';
import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  bool? result;

  Future<void> openSheet(
    WidgetTester tester, {
    ChallengeType type = ChallengeType.run,
    Size size = smallPhone,
    double textScale = 1,
  }) async {
    result = null;
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async =>
                  result = await confirmLeave(context, challenge(type: type)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
      size: size,
      textScale: textScale,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks, names the type, and Leave challenge confirms', (
    tester,
  ) async {
    await openSheet(tester, type: ChallengeType.swim);

    expect(find.text('Leave this challenge?'), findsOneWidget);
    expect(
      find.text(
        'You can join again while it is open, if no other swim challenge '
        'overlaps it.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Leave challenge'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('Leave this challenge?'), findsNothing);
  });

  testWidgets('Keep it does not leave', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('dismissing the sheet does not leave', (tester) async {
    await openSheet(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  for (final size in [smallPhone, largePhone]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('fits and is accessible on $size at text x$textScale', (
        tester,
      ) async {
        await openSheet(tester, size: size, textScale: textScale);

        expectNoLayoutException(tester);
        await expectAccessible(tester);
      });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import 'package:stridequest/features/challenges/presentation/widgets/challenge_action_bar.dart';

import '../../../../helpers/challenge_fixtures.dart';
import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/pump_screen.dart';

final _open = DateTime.utc(2026, 10, 17);
final _after = DateTime.utc(2026, 11, 2);
const _other = BlockingChallenge(id: 2, title: 'Old Quarter 50K Steps');

void main() {
  ChallengeAction? tapped;
  var left = false;

  setUp(() {
    tapped = null;
    left = false;
  });

  Future<void> pumpBar(
    WidgetTester tester,
    Challenge challenge, {
    DateTime? now,
    bool busy = false,
    Size size = smallPhone,
    double textScale = 1,
  }) => pumpScreen(
    tester,
    Scaffold(
      bottomNavigationBar: ChallengeActionBar(
        challenge: challenge,
        now: now ?? _open,
        busy: busy,
        onAction: (action) => tapped = action,
        onLeave: () => left = true,
      ),
    ),
    size: size,
    textScale: textScale,
    // A progress indicator spins for ever.
    settle: !busy,
  );

  FilledButton filled(WidgetTester tester) =>
      tester.widget(find.byType(FilledButton));

  group('not joined', () {
    testWidgets('Join Challenge joins', (tester) async {
      await pumpBar(tester, challenge());

      await tester.tap(find.text('Join Challenge'));

      expect(tapped, ChallengeAction.join);
      expect(find.text(endedMessage), findsNothing);
    });

    testWidgets('an overlapping challenge disables Join and says which', (
      tester,
    ) async {
      await pumpBar(tester, challenge(blockedBy: _other));

      expect(filled(tester).onPressed, isNull);
      expect(find.text(blockedMessage(_other)), findsOneWidget);
      expect(find.textContaining('“Old Quarter 50K Steps”'), findsOneWidget);
    });

    testWidgets('an ended challenge disables Join and says so', (tester) async {
      await pumpBar(tester, challenge(), now: _after);

      expect(filled(tester).onPressed, isNull);
      expect(find.text(endedMessage), findsOneWidget);
    });

    testWidgets('the end wins over an overlap as the reason', (tester) async {
      await pumpBar(tester, challenge(blockedBy: _other), now: _after);

      expect(find.text(endedMessage), findsOneWidget);
      expect(find.textContaining('Old Quarter'), findsNothing);
    });

    testWidgets('busy shows progress and cannot be tapped again', (
      tester,
    ) async {
      await pumpBar(tester, challenge(), busy: true);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(filled(tester).onPressed, isNull);
    });
  });

  group('active', () {
    final active = challenge(enrollment: enrolled());

    testWidgets('Pause and Leave', (tester) async {
      await pumpBar(tester, active);

      expect(find.widgetWithText(OutlinedButton, 'Pause'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Leave'), findsOneWidget);
      expect(find.text('Join Challenge'), findsNothing);

      await tester.tap(find.text('Pause'));
      expect(tapped, ChallengeAction.pause);
      await tester.tap(find.text('Leave'));
      expect(left, isTrue);
    });

    testWidgets('an ended challenge can still be paused or left', (
      tester,
    ) async {
      await pumpBar(tester, active, now: _after);

      await tester.tap(find.text('Pause'));

      expect(tapped, ChallengeAction.pause);
      expect(find.text(endedMessage), findsNothing);
    });

    testWidgets('busy disables both', (tester) async {
      await pumpBar(tester, active, busy: true);

      for (final label in ['Pause', 'Leave']) {
        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, label),
        );
        expect(button.onPressed, isNull);
      }
    });
  });

  group('paused', () {
    final paused = challenge(enrollment: enrolled(EnrollmentStatus.paused));

    testWidgets('Resume and Leave', (tester) async {
      await pumpBar(tester, paused);

      await tester.tap(find.text('Resume'));

      expect(tapped, ChallengeAction.resume);
      expect(find.text('Pause'), findsNothing);
      await tester.tap(find.text('Leave'));
      expect(left, isTrue);
    });

    testWidgets('Resume is disabled while another challenge is active', (
      tester,
    ) async {
      await pumpBar(
        tester,
        challenge(
          enrollment: enrolled(EnrollmentStatus.paused),
          blockedBy: _other,
        ),
      );

      final resume = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Resume'),
      );
      expect(resume.onPressed, isNull);
      expect(find.text(blockedMessage(_other)), findsOneWidget);
    });

    testWidgets('Resume is disabled once it has ended, Leave is not', (
      tester,
    ) async {
      await pumpBar(tester, paused, now: _after);

      final resume = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Resume'),
      );
      expect(resume.onPressed, isNull);
      expect(find.text(endedMessage), findsOneWidget);
      await tester.tap(find.text('Leave'));
      expect(left, isTrue);
    });
  });

  group('screen quality', () {
    final states = <String, (Challenge, DateTime?)>{
      'join': (challenge(), null),
      'blocked': (challenge(blockedBy: _other), null),
      'ended': (challenge(), _after),
      'active': (challenge(enrollment: enrolled()), null),
      'paused blocked': (
        challenge(
          enrollment: enrolled(EnrollmentStatus.paused),
          blockedBy: _other,
        ),
        null,
      ),
    };
    for (final entry in states.entries) {
      for (final size in [smallPhone, largePhone]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '${entry.key} fits and is accessible on $size at text x$textScale',
            (tester) async {
              await pumpBar(
                tester,
                entry.value.$1,
                now: entry.value.$2,
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

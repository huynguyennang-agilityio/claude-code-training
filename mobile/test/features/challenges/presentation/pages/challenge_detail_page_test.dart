import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenge_detail_page.dart';

import '../../../../helpers/challenge_fixtures.dart';
import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/mock_challenge_blocs.dart';
import '../../../../helpers/pump_screen.dart';

/// 13 days, 11 hours and 13 minutes before the end of the default challenge.
final _now = DateTime.utc(2026, 10, 17, 12, 46, 53);

void main() {
  late MockChallengeDetailBloc bloc;

  setUpAll(() => registerFallbackValue(const ChallengeDetailStarted(0)));
  setUp(() => bloc = MockChallengeDetailBloc());

  Future<void> pumpPage(
    WidgetTester tester,
    ChallengeDetailState state, {
    DateTime? now,
    Size size = smallPhone,
    double textScale = 1,
    bool settle = true,
  }) async {
    whenListen(
      bloc,
      const Stream<ChallengeDetailState>.empty(),
      initialState: state,
    );
    await pumpScreen(
      tester,
      BlocProvider<ChallengeDetailBloc>.value(
        value: bloc,
        child: ChallengeDetailPage(challengeId: 1, clock: () => now ?? _now),
      ),
      size: size,
      textScale: textScale,
      settle: settle,
    );
  }

  ChallengeDetailLoaded loaded([Challenge? value]) =>
      ChallengeDetailLoaded(value ?? challenge());

  /// Scrolls until [finder] is on screen, then a little more so it is clear of
  /// the edge.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200);
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pump();
  }

  group('a loaded challenge', () {
    testWidgets('shows what it is', (tester) async {
      await pumpPage(tester, loaded());

      expect(find.text('Old Quarter 50K Steps'), findsOneWidget);
      expect(find.text('Run'), findsOneWidget);
      expect(find.text('Solo'), findsOneWidget);
      expect(find.text('Hồ Hoàn Kiem'), findsOneWidget);
      expect(find.text('Oct 1 – Oct 31'), findsOneWidget);
      expect(find.text('STEP GOAL'), findsOneWidget);
      expect(find.text('50k'), findsOneWidget);
    });

    testWidgets('a swim shows its distance goal in kilometres', (tester) async {
      await pumpPage(
        tester,
        loaded(
          challenge(
            title: 'Mỹ Khê Bay 20 km',
            type: ChallengeType.swim,
            target: 20000,
            medalList: const [
              Medal(
                tier: MedalTier.gold,
                name: 'Bay',
                threshold: 20000,
                imageUrl: medalUrl,
              ),
            ],
          ),
        ),
      );

      expect(find.text('DISTANCE GOAL'), findsOneWidget);
      expect(find.text('20 km'), findsWidgets);
      expect(find.text('Swim'), findsOneWidget);
    });

    testWidgets('counts down to the end while it is open', (tester) async {
      await pumpPage(tester, loaded());

      expect(find.text('Challenge ends in'), findsOneWidget);
      expect(find.text('13'), findsWidgets);
      for (final label in ['Days', 'Hrs', 'Min', 'Sec']) {
        expect(find.text(label), findsOneWidget);
      }
      // 13 days, 11 hours, 13 minutes and 7 seconds from `_now` to Oct 31 00:00 UTC.
      expect(find.text('11'), findsOneWidget);
      expect(find.text('07'), findsOneWidget);
    });

    testWidgets('counts down to the start before it begins', (tester) async {
      await pumpPage(
        tester,
        loaded(challenge(startsAt: DateTime.utc(2026, 10, 20))),
      );

      expect(find.text('Challenge starts in'), findsOneWidget);
      expect(find.text('Challenge ends in'), findsNothing);
    });

    testWidgets('has no countdown once it has ended', (tester) async {
      await pumpPage(tester, loaded(), now: DateTime.utc(2026, 11, 2));

      expect(find.text('Challenge ends in'), findsNothing);
      expect(find.text('Challenge starts in'), findsNothing);
      expect(find.text('Days'), findsNothing);
    });

    testWidgets('the countdown ticks every second', (tester) async {
      var now = _now;
      whenListen(
        bloc,
        const Stream<ChallengeDetailState>.empty(),
        initialState: loaded(),
      );
      await pumpScreen(
        tester,
        BlocProvider<ChallengeDetailBloc>.value(
          value: bloc,
          child: ChallengeDetailPage(challengeId: 1, clock: () => now),
        ),
      );
      expect(find.text('07'), findsOneWidget);

      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('04'), findsOneWidget);
    });

    testWidgets('lists the details and opens the terms', (tester) async {
      await pumpPage(tester, loaded());
      await scrollTo(tester, find.text('Terms and Conditions'));

      expect(find.text('Oct 1 – Oct 31, 2026'), findsOneWidget);
      expect(find.text('Steps goal: 50,000'), findsOneWidget);
      expect(find.text('Steps are read from Apple Health.'), findsNothing);

      await tester.tap(find.text('Terms and Conditions'));
      await tester.pump();
      expect(find.text('Steps are read from Apple Health.'), findsOneWidget);

      await tester.tap(find.text('Terms and Conditions'));
      await tester.pump();
      expect(find.text('Steps are read from Apple Health.'), findsNothing);
    });

    testWidgets('no terms means no terms row', (tester) async {
      await pumpPage(tester, loaded(challenge(terms: '  ')));
      await scrollTo(tester, find.text('Steps goal: 50,000'));

      expect(find.text('Terms and Conditions'), findsNothing);
    });

    testWidgets('shows how many joined', (tester) async {
      await pumpPage(tester, loaded());
      await scrollTo(tester, find.text('Participants'));

      expect(find.text('+813'), findsOneWidget);
    });

    testWidgets('nobody joined yet', (tester) async {
      await pumpPage(tester, loaded(challenge(participants: 0)));
      await scrollTo(tester, find.text('Participants'));

      expect(find.text('Be the first to join'), findsOneWidget);
    });

    testWidgets('shows the three medal checkpoints', (tester) async {
      await pumpPage(tester, loaded());
      await scrollTo(tester, find.text('Medals'));

      for (final tier in ['Bronze', 'Silver', 'Gold']) {
        expect(find.text(tier), findsOneWidget);
      }
      expect(find.text('20,000'), findsOneWidget);
      expect(find.text('35,000'), findsOneWidget);
      expect(find.text('50,000'), findsOneWidget);
    });

    testWidgets('the rules are the description as text', (tester) async {
      await pumpPage(
        tester,
        loaded(challenge(description: 'Go <b>far</b>.\n\n- first')),
      );
      await scrollTo(tester, find.text('Challenge rules'));

      expect(
        find.textContaining('Go <b>far</b>.', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('first', findRichText: true), findsOneWidget);
    });
  });

  group('other states', () {
    testWidgets('loading shows progress and a back button', (tester) async {
      await pumpPage(tester, const ChallengeDetailLoading(), settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('an error shows its message and Try again reloads', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const ChallengeDetailFailed(
          ChallengeFailure(ChallengeFailureCode.challengeNotFound),
        ),
      );

      expect(find.text('This challenge is not available.'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));

      verify(() => bloc.add(const ChallengeDetailStarted(1))).called(1);
    });
  });

  group('screen quality', () {
    final states = <String, ChallengeDetailState>{
      'open': loaded(),
      'upcoming': loaded(challenge(startsAt: DateTime.utc(2026, 10, 20))),
      'error': const ChallengeDetailFailed(
        ChallengeFailure(ChallengeFailureCode.network),
      ),
    };
    for (final entry in states.entries) {
      for (final size in [smallPhone, largePhone]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '${entry.key} fits and is accessible on $size at text x$textScale',
            (tester) async {
              await pumpPage(
                tester,
                entry.value,
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

    testWidgets('the whole page scrolls without overflow at text x2', (
      tester,
    ) async {
      await pumpPage(tester, loaded(), textScale: 2);
      for (final end in ['Medals', 'Challenge rules']) {
        await scrollTo(tester, find.text(end));
        expectNoLayoutException(tester);
      }
    });
  });
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenges_page.dart';

import '../../../../helpers/challenge_fixtures.dart';
import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/mock_challenge_blocs.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  late MockChallengesBloc bloc;

  setUpAll(() {
    registerFallbackValue(const ChallengesStarted());
  });
  setUp(() {
    bloc = MockChallengesBloc();
    when(() => bloc.isClosed).thenReturn(false);
  });

  Future<void> pumpPage(
    WidgetTester tester,
    ChallengesState state, {
    Size size = smallPhone,
    double textScale = 1,
    bool settle = true,
  }) async {
    whenListen(
      bloc,
      const Stream<ChallengesState>.empty(),
      initialState: state,
    );
    await pumpScreen(
      tester,
      BlocProvider<ChallengesBloc>.value(
        value: bloc,
        child: const ChallengesPage(searchDelay: Duration(milliseconds: 10)),
      ),
      size: size,
      textScale: textScale,
      settle: settle,
    );
  }

  /// Scrolls the vertical list until [finder] is on screen.
  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );

  final cards = [
    summary(),
    summary(
      id: 2,
      title: 'Mỹ Khê Bay 20 km',
      type: ChallengeType.swim,
      target: 20000,
      city: 'Đà Nẵng',
      participants: 860,
      enrollment: enrolled(),
    ),
    summary(
      id: 3,
      title: 'Saigon Ride',
      type: ChallengeType.cycle,
      target: 100000,
      city: null,
      participants: 0,
      enrollment: enrolled(EnrollmentStatus.paused),
    ),
  ];
  ChallengesState ready([List<ChallengeSummary>? items]) =>
      ChallengesState(status: ChallengesStatus.ready, items: items ?? cards);

  group('the list', () {
    testWidgets('shows the title, the search, the chips and the cards', (
      tester,
    ) async {
      await pumpPage(tester, ready());

      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Search challenges'), findsOneWidget);
      for (final chip in ['All', 'Run', 'Swim', 'Cycle']) {
        expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget);
      }
      expect(find.text('Old Quarter 50K Steps'), findsOneWidget);
      expect(find.text('Oct 1 – Oct 31'), findsWidgets);
      expect(find.text('50,000 steps'), findsOneWidget);
      expect(find.text('1.2K joined'), findsOneWidget);
      expect(find.text('Hà Nội'), findsOneWidget);
    });

    testWidgets('a card is Join, Joined or Paused', (tester) async {
      await pumpPage(tester, ready());

      expect(find.widgetWithText(FilledButton, 'Join'), findsOneWidget);
      expect(find.text('Joined'), findsOneWidget);
      await scrollTo(tester, find.text('Paused'));
      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('a swim and a ride show kilometres', (tester) async {
      await pumpPage(tester, ready());

      expect(find.text('20 km'), findsOneWidget);
      await scrollTo(tester, find.text('100 km'));
      expect(find.text('100 km'), findsOneWidget);
    });

    testWidgets('the chip of the current type is selected', (tester) async {
      await pumpPage(
        tester,
        ChallengesState(
          status: ChallengesStatus.ready,
          items: cards,
          type: ChallengeType.swim,
        ),
      );

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Swim'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
            .selected,
        isFalse,
      );
    });
  });

  group('other states', () {
    testWidgets('loading shows progress', (tester) async {
      await pumpPage(tester, const ChallengesState(), settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Old Quarter 50K Steps'), findsNothing);
    });

    testWidgets('empty says nothing is open', (tester) async {
      await pumpPage(tester, ready(const []));

      expect(
        find.text('No challenges are open yet. Check back soon.'),
        findsOneWidget,
      );
    });

    testWidgets('empty after a search says nothing matches', (tester) async {
      await pumpPage(
        tester,
        const ChallengesState(status: ChallengesStatus.ready, query: 'zzz'),
      );

      expect(find.text('No challenges match your search.'), findsOneWidget);
    });

    testWidgets('an error shows its message and Try again reloads', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const ChallengesState(
          status: ChallengesStatus.failed,
          failure: ChallengeFailure(ChallengeFailureCode.network),
        ),
      );

      expect(
        find.text('Cannot reach StrideQuest. Check your connection.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));

      verify(() => bloc.add(const ChallengesStarted())).called(1);
    });

    testWidgets('a failed next page offers to try again', (tester) async {
      await pumpPage(
        tester,
        ChallengesState(
          status: ChallengesStatus.ready,
          items: [summary()],
          nextCursor: 'c1',
          moreFailed: true,
        ),
      );

      await tester.tap(find.text('Could not load more. Try again'));

      verify(() => bloc.add(const ChallengesMoreRequested())).called(1);
    });

    testWidgets('reaching the end of a page asks for the next one', (
      tester,
    ) async {
      await pumpPage(
        tester,
        ChallengesState(
          status: ChallengesStatus.ready,
          items: [summary()],
          nextCursor: 'c1',
        ),
        settle: false,
      );
      await tester.pump();

      verify(
        () => bloc.add(const ChallengesMoreRequested()),
      ).called(greaterThan(0));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('joining from a card', () {
    testWidgets('Join asks the bloc to join that challenge', (tester) async {
      await pumpPage(tester, ready());

      await tester.tap(find.widgetWithText(FilledButton, 'Join'));

      verify(() => bloc.add(const ChallengesJoinRequested(1))).called(1);
    });

    testWidgets('the card whose join is running cannot be tapped again', (
      tester,
    ) async {
      await pumpPage(
        tester,
        ChallengesState(
          status: ChallengesStatus.ready,
          items: cards,
          joiningId: 1,
        ),
      );

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Join'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a refused join shows why', (tester) async {
      final states = StreamController<ChallengesState>();
      addTearDown(states.close);
      whenListen(bloc, states.stream, initialState: ready());
      await pumpScreen(
        tester,
        BlocProvider<ChallengesBloc>.value(
          value: bloc,
          child: const ChallengesPage(),
        ),
      );

      states.add(
        ChallengesState(
          status: ChallengesStatus.ready,
          items: cards,
          notice: const ChallengeFailure(
            ChallengeFailureCode.overlappingChallenge,
            serverMessage: 'You are already in “X”.',
          ),
          noticeCount: 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You are already in “X”.'), findsOneWidget);
    });
  });

  group('searching and filtering', () {
    testWidgets('typing searches after a short pause', (tester) async {
      await pumpPage(tester, ready());

      await tester.enterText(find.byType(TextField), 'lake');
      verifyNever(() => bloc.add(any(that: isA<ChallengesFilterChanged>())));
      await tester.pump(const Duration(milliseconds: 20));

      verify(
        () => bloc.add(const ChallengesFilterChanged(query: 'lake')),
      ).called(1);
    });

    testWidgets('keystrokes in quick succession search once', (tester) async {
      await pumpPage(tester, ready());

      await tester.enterText(find.byType(TextField), 'l');
      await tester.pump(const Duration(milliseconds: 4));
      await tester.enterText(find.byType(TextField), 'la');
      await tester.pump(const Duration(milliseconds: 20));

      verify(
        () => bloc.add(const ChallengesFilterChanged(query: 'la')),
      ).called(1);
    });

    testWidgets('a chip filters by type and keeps the search text', (
      tester,
    ) async {
      await pumpPage(tester, ready());
      await tester.enterText(find.byType(TextField), 'bay');
      await tester.pump(const Duration(milliseconds: 20));
      clearInteractions(bloc);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Swim'));

      verify(
        () => bloc.add(
          const ChallengesFilterChanged(type: ChallengeType.swim, query: 'bay'),
        ),
      ).called(1);
    });

    testWidgets('clearing the search shows all again at once', (tester) async {
      await pumpPage(tester, ready());
      await tester.enterText(find.byType(TextField), 'lake');
      await tester.pump(const Duration(milliseconds: 20));
      clearInteractions(bloc);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();

      verify(() => bloc.add(const ChallengesFilterChanged())).called(1);
      expect(find.byTooltip('Clear search'), findsNothing);
    });
  });

  group('screen quality', () {
    final states = {
      'list': ready(),
      'empty': ready(const []),
      'error': const ChallengesState(
        status: ChallengesStatus.failed,
        failure: ChallengeFailure(ChallengeFailureCode.network),
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

    testWidgets('loading fits on a small phone at text x2', (tester) async {
      await pumpPage(
        tester,
        const ChallengesState(),
        textScale: 2,
        settle: false,
      );

      expectNoLayoutException(tester);
    });
  });
}

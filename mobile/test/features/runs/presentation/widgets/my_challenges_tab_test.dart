import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/theme/app_theme.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/presentation/bloc/my_challenges_bloc.dart';
import 'package:stridequest/features/runs/presentation/widgets/my_challenge_card.dart';
import 'package:stridequest/features/runs/presentation/widgets/my_challenges_tab.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/pump_screen.dart';
import '../../../../helpers/runs_fixtures.dart';

final _states = <String, MyChallengesState>{
  'loading': const MyChallengesState(),
  'empty': const MyChallengesState(status: MyChallengesStatus.ready),
  'error': const MyChallengesState(
    status: MyChallengesStatus.failed,
    failure: RunsFailure(RunsFailureCode.network),
  ),
  'list': MyChallengesState(
    status: MyChallengesStatus.ready,
    items: [
      myChallenge(),
      myChallenge(
        id: 9,
        title: 'Mỹ Khê Bay 20 km',
        type: ChallengeType.swim,
        target: 20000,
        city: 'Đà Nẵng',
      ),
      myChallenge(
        id: 11,
        title: 'Hanoi Autumn 30K Steps',
        startsAt: DateTime.utc(2026, 11, 1),
        started: false,
        current: 0,
        percent: 0,
      ),
      myChallenge(id: 12, title: 'Paused run', status: EnrollmentStatus.paused),
    ],
  ),
  'list with more': MyChallengesState(
    status: MyChallengesStatus.ready,
    items: [myChallenge()],
    nextCursor: 'next',
    loadingMore: true,
  ),
  'list, next page failed': MyChallengesState(
    status: MyChallengesStatus.ready,
    items: [myChallenge()],
    nextCursor: 'next',
    moreFailed: true,
  ),
};

MockMyChallengesBloc _blocIn(MyChallengesState state) {
  final bloc = MockMyChallengesBloc();
  when(() => bloc.isClosed).thenReturn(false);
  whenListen(
    bloc,
    const Stream<MyChallengesState>.empty(),
    initialState: state,
  );
  return bloc;
}

Widget _tab(MockMyChallengesBloc bloc) => Scaffold(
  body: BlocProvider<MyChallengesBloc>.value(
    value: bloc,
    child: const MyChallengesTab(),
  ),
);

void main() {
  testWidgets('loading shows a spinner', (tester) async {
    await pumpScreen(tester, _tab(_blocIn(_states['loading']!)), settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('the list', () {
    Future<void> pumpList(WidgetTester tester) =>
        pumpScreen(tester, _tab(_blocIn(_states['list']!)));

    testWidgets('a run in progress shows the bar, the percent and the amount', (
      tester,
    ) async {
      await pumpList(tester);

      expect(find.text('Old Quarter 50K Steps'), findsOneWidget);
      expect(find.text('Goal 18%'), findsOneWidget);
      expect(find.text('9,000 / 50,000 steps'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator).first,
      );
      expect(bar.value, 0.18);
    });

    testWidgets('a swim shows the note and no percentage', (tester) async {
      await pumpList(tester);

      expect(find.text('Progress for swim comes soon'), findsOneWidget);
      expect(find.text('Mỹ Khê Bay 20 km'), findsOneWidget);
    });

    testWidgets('a challenge that has not started says when it starts', (
      tester,
    ) async {
      await pumpList(tester);
      await tester.scrollUntilVisible(find.text('Hanoi Autumn 30K Steps'), 200);

      expect(find.text('Starts Nov 1'), findsOneWidget);
    });

    testWidgets('a paused challenge has the Paused pill and keeps its bar', (
      tester,
    ) async {
      await pumpList(tester);
      await tester.scrollUntilVisible(find.text('Paused run'), 200);

      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets('a card reads as one button with its title and goal', (
      tester,
    ) async {
      await pumpList(tester);

      expect(
        find.bySemanticsLabel('Old Quarter 50K Steps, goal 18 percent'),
        findsOneWidget,
      );
    });

    testWidgets('a long list asks for the next page at its end', (
      tester,
    ) async {
      final bloc = _blocIn(
        MyChallengesState(
          status: MyChallengesStatus.ready,
          items: [myChallenge()],
          nextCursor: 'next',
        ),
      );
      await pumpScreen(tester, _tab(bloc), settle: false);
      await tester.pump();
      await tester.pump();

      verify(() => bloc.add(const MyChallengesMoreRequested())).called(1);
    });

    testWidgets('a failed next page offers a retry', (tester) async {
      final bloc = _blocIn(_states['list, next page failed']!);
      await pumpScreen(tester, _tab(bloc));

      await tester.tap(find.text('Could not load more. Try again'));

      verify(() => bloc.add(const MyChallengesMoreRequested())).called(1);
    });
  });

  testWidgets('empty offers to browse the challenges', (tester) async {
    final router = GoRouter(
      initialLocation: '/active',
      routes: [
        GoRoute(
          path: '/active',
          builder: (context, state) => _tab(_blocIn(_states['empty']!)),
        ),
        GoRoute(
          path: '/challenges',
          builder: (context, state) =>
              const Scaffold(body: Text('Challenges tab')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('No challenge in progress'), findsOneWidget);
    expect(
      find.text('Join a challenge and your progress will show up here.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Browse challenges'));
    await tester.pumpAndSettle();

    expect(find.text('Challenges tab'), findsOneWidget);
  });

  testWidgets('error says why and Try again reloads', (tester) async {
    final bloc = _blocIn(_states['error']!);
    await pumpScreen(tester, _tab(bloc));

    expect(
      find.text('Cannot reach StrideQuest. Check your connection.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));

    verify(() => bloc.add(const MyChallengesStarted())).called(1);
  });

  testWidgets('tapping a card opens the challenge detail by id', (
    tester,
  ) async {
    final bloc = _blocIn(
      MyChallengesState(
        status: MyChallengesStatus.ready,
        items: [myChallenge(id: 42)],
      ),
    );
    final router = GoRouter(
      initialLocation: '/active',
      routes: [
        GoRoute(path: '/active', builder: (context, state) => _tab(bloc)),
        GoRoute(
          path: '/challenges/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Detail ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MyChallengeCard));
    await tester.pumpAndSettle();

    expect(find.text('Detail 42'), findsOneWidget);
  });

  group('screen quality', () {
    for (final entry in _states.entries) {
      for (final size in [smallPhone, largePhone]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '${entry.key} fits and is accessible on $size at text x$textScale',
            (tester) async {
              final settle =
                  entry.key != 'loading' && entry.key != 'list with more';
              await pumpScreen(
                tester,
                _tab(_blocIn(entry.value)),
                size: size,
                textScale: textScale,
                settle: settle,
              );
              if (!settle) await tester.pump();

              expectNoLayoutException(tester);
              await expectAccessible(tester);
            },
          );
        }
      }
    }
  });
}

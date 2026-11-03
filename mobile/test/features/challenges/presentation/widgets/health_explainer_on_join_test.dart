import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenge_detail_page.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenges_page.dart';
import 'package:stridequest/features/challenges/presentation/widgets/health_explainer_on_join.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_notice_bloc.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_sheets.dart';

import '../../../../helpers/challenge_fixtures.dart';
import '../../../../helpers/challenges_di.dart';
import '../../../../helpers/health_fixtures.dart';
import '../../../../helpers/pump_screen.dart';

final _now = DateTime.utc(2026, 10, 17, 12);

/// One way to join: where the page is and how to join a second time.
typedef _Entry = ({
  Widget Function() page,
  String join,
  Future<void> Function(WidgetTester) joinAgain,
});

void main() {
  late FakeChallengeRepository challenges;
  late FakeHealthRepository health;
  late MockGetHealthNotice getNotice;
  late MockHealthSync sync;

  setUp(() {
    challenges = FakeChallengeRepository(
      items: [
        summary(),
        summary(id: 2, title: 'Mỹ Khê Bay 20 km'),
      ],
    )..detail = challenge();
    challenges.onAction = (action, id) => switch (action) {
      'leave' => challenge(id: id),
      'pause' => challenge(
        id: id,
        enrollment: enrolled(EnrollmentStatus.paused),
      ),
      _ => challenge(id: id, enrollment: enrolled()),
    };
    health = FakeHealthRepository(const HealthAccess.denied())
      ..recordClearsDue = true;
    getNotice = noticeAnswering(HealthNotice.askable);
    sync = MockHealthSync();
    when(() => sync.syncNow()).thenAnswer((_) async {});
    registerChallengeBlocs(
      repository: challenges,
      notice: getNotice,
      health: health,
      sync: sync,
    );
    addTearDown(getIt.reset);
  });

  // The two entry points, wired like the routes in `app_router.dart`.
  final entries = <String, _Entry>{
    'a card on the list': (
      page: () => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                getIt<ChallengesBloc>()..add(const ChallengesStarted()),
          ),
          BlocProvider(
            create: (_) =>
                getIt<HealthNoticeBloc>()..add(const HealthNoticeStarted()),
          ),
        ],
        child: const HealthExplainerOnJoin<ChallengesBloc, ChallengesState>(
          joined: challengesJoined,
          child: ChallengesPage(),
        ),
      ),
      join: 'Join',
      // The other card is still open for joining.
      joinAgain: (tester) async {
        final other = find.widgetWithText(FilledButton, 'Join');
        await tester.ensureVisible(other);
        await tester.pumpAndSettle();
        await tester.tap(other);
        await tester.pumpAndSettle();
      },
    ),
    'the detail screen': (
      page: () => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                getIt<ChallengeDetailBloc>()
                  ..add(const ChallengeDetailStarted(1)),
          ),
          BlocProvider(
            create: (_) =>
                getIt<HealthNoticeBloc>()..add(const HealthNoticeStarted()),
          ),
        ],
        child: HealthExplainerOnJoin<ChallengeDetailBloc, ChallengeDetailState>(
          joined: challengeDetailJoined,
          child: ChallengeDetailPage(challengeId: 1, clock: () => _now),
        ),
      ),
      join: 'Join Challenge',
      joinAgain: (tester) async {
        tester
            .element(find.byType(ChallengeDetailPage))
            .read<ChallengeDetailBloc>()
            .add(const ChallengeActionRequested(ChallengeAction.leave));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Join Challenge'));
        await tester.pumpAndSettle();
      },
    ),
  };

  for (final MapEntry(key: name, value: entry) in entries.entries) {
    group('joining from $name', () {
      Future<void> join(WidgetTester tester) async {
        await pumpScreen(tester, entry.page());
        await tester.tap(find.widgetWithText(FilledButton, entry.join).first);
        await tester.pumpAndSettle();
      }

      testWidgets('Not now closes the sheet; the user stays joined', (
        tester,
      ) async {
        await join(tester);

        expect(find.byType(HealthExplainerSheet), findsOneWidget);
        expect(health.explainerShown, 1);
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();

        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(find.text('Joined'), findsOneWidget);
        expect(challenges.actions, ['join 1']);
        expect(health.requests, 0);
        expect(health.explainerShown, 1);
      });

      testWidgets('Continue asks for access', (tester) async {
        await join(tester);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(health.requests, 1);
        expect(health.explainerShown, 1);
        expect(find.text('Joined'), findsOneWidget);
      });

      testWidgets('dismissing the sheet still counts as shown', (tester) async {
        await join(tester);

        // Closed without a button, as a back gesture or a tap outside does.
        Navigator.of(tester.element(find.byType(HealthExplainerSheet))).pop();
        await tester.pumpAndSettle();

        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(health.explainerShown, 1);
        expect(health.requests, 0);
      });

      testWidgets('no sheet when access is already granted', (tester) async {
        when(
          () => getNotice(clock: any(named: 'clock')),
        ).thenAnswer((_) async => HealthNotice.none);

        await join(tester);

        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(health.explainerShown, 0);
        expect(find.text('Joined'), findsOneWidget);
      });

      testWidgets('no sheet when it was shown within 7 days', (tester) async {
        health.due = false;

        await join(tester);

        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(health.explainerShown, 0);
        expect(find.text('Joined'), findsOneWidget);
      });

      testWidgets('a second join in the same session does not ask again', (
        tester,
      ) async {
        await join(tester);
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();

        await entry.joinAgain(tester);

        expect(
          challenges.actions.where((a) => a.startsWith('join')),
          hasLength(2),
        );
        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(health.explainerShown, 1);
      });

      testWidgets('a refused join opens nothing', (tester) async {
        await pumpScreen(tester, entry.page());
        // Forget the check that loads the banner when the route opens.
        clearInteractions(getNotice);
        challenges.failure = const ChallengeFailure(
          ChallengeFailureCode.challengeEnded,
        );
        await tester.tap(find.widgetWithText(FilledButton, entry.join).first);
        await tester.pumpAndSettle();

        verifyNever(() => getNotice(clock: any(named: 'clock')));
        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(health.explainerShown, 0);
      });

      testWidgets('the join finishes while the health check is slow', (
        tester,
      ) async {
        final gate = Completer<HealthNotice>();
        when(
          () => getNotice(clock: any(named: 'clock')),
        ).thenAnswer((_) => gate.future);

        await join(tester);

        expect(find.text('Joined'), findsOneWidget);
        expect(challenges.actions, ['join 1']);
        expect(find.byType(HealthExplainerSheet), findsNothing);

        gate.complete(HealthNotice.askable);
        await tester.pumpAndSettle();
        expect(find.byType(HealthExplainerSheet), findsOneWidget);
      });

      testWidgets('nothing opens or is recorded when another route is on top', (
        tester,
      ) async {
        final gate = Completer<HealthNotice>();
        when(
          () => getNotice(clock: any(named: 'clock')),
        ).thenAnswer((_) => gate.future);

        await join(tester);
        unawaited(
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('elsewhere')),
                ),
              ),
        );
        await tester.pumpAndSettle();
        gate.complete(HealthNotice.askable);
        await tester.pumpAndSettle();

        expect(find.text('elsewhere'), findsOneWidget);
        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(health.explainerShown, 0);
      });

      testWidgets('the sheet opens from inside a tab navigator', (
        tester,
      ) async {
        // Like the shell: the screen sits in a nested navigator.
        await pumpScreen(
          tester,
          Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => entry.page()),
          ),
        );
        await tester.tap(find.widgetWithText(FilledButton, entry.join).first);
        await tester.pumpAndSettle();

        expect(find.byType(HealthExplainerSheet), findsOneWidget);
        expect(health.explainerShown, 1);
      });

      testWidgets('nothing opens or is recorded once the user left the tab', (
        tester,
      ) async {
        final gate = Completer<HealthNotice>();
        when(
          () => getNotice(clock: any(named: 'clock')),
        ).thenAnswer((_) => gate.future);
        final active = ValueNotifier(true);
        addTearDown(active.dispose);

        // Like the shell: a tab the user left stays mounted, its tickers off.
        await pumpScreen(
          tester,
          ValueListenableBuilder(
            valueListenable: active,
            builder: (_, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
            child: entry.page(),
          ),
        );
        await tester.tap(find.widgetWithText(FilledButton, entry.join).first);
        await tester.pump();
        active.value = false;
        await tester.pump();
        gate.complete(HealthNotice.askable);
        await tester.pumpAndSettle();

        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(health.explainerShown, 0);
      });

      testWidgets(
        'nothing opens when the root navigator covers the tab navigator',
        (tester) async {
          final gate = Completer<HealthNotice>();
          when(
            () => getNotice(clock: any(named: 'clock')),
          ).thenAnswer((_) => gate.future);

          // Like the shell: the screen sits in a nested navigator, and the
          // detail screen is pushed on the root one above it.
          await pumpScreen(
            tester,
            Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => entry.page()),
            ),
          );
          await tester.tap(find.widgetWithText(FilledButton, entry.join).first);
          await tester.pump();
          unawaited(
            tester
                .state<NavigatorState>(find.byType(Navigator).first)
                .push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('elsewhere')),
                  ),
                ),
          );
          await tester.pumpAndSettle();
          gate.complete(HealthNotice.askable);
          await tester.pumpAndSettle();

          expect(find.text('elsewhere'), findsOneWidget);
          expect(find.byType(HealthExplainerSheet), findsNothing);
          expect(health.explainerShown, 0);
        },
      );

      testWidgets('the join is unaffected when the health check throws', (
        tester,
      ) async {
        final reported = <Object>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) => reported.add(details.exception);
        addTearDown(() => FlutterError.onError = previous);
        await pumpScreen(tester, entry.page());
        when(
          () => getNotice(clock: any(named: 'clock')),
        ).thenAnswer((_) async => throw StateError('no health'));
        reported.clear();
        await tester.tap(find.widgetWithText(FilledButton, entry.join).first);
        await tester.pumpAndSettle();

        expect(find.text('Joined'), findsOneWidget);
        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(reported, [isA<StateError>()]);
      });
    });
  }

  group('the detail screen, with an actual join missing', () {
    testWidgets('pausing and resuming never ask', (tester) async {
      challenges.detail = challenge(enrollment: enrolled());
      await pumpScreen(tester, entries.values.last.page());
      // Forget the check that loads the banner when the route opens.
      clearInteractions(getNotice);
      final bloc = tester
          .element(find.byType(ChallengeDetailPage))
          .read<ChallengeDetailBloc>();

      bloc.add(const ChallengeActionRequested(ChallengeAction.pause));
      await tester.pumpAndSettle();
      bloc.add(const ChallengeActionRequested(ChallengeAction.resume));
      await tester.pumpAndSettle();

      expect(challenges.actions, ['pause 1', 'resume 1']);
      verifyNever(() => getNotice(clock: any(named: 'clock')));
      expect(find.byType(HealthExplainerSheet), findsNothing);
    });
  });
}

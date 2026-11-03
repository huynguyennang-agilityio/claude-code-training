import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenge_detail_page.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenges_page.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/repositories/health_repository.dart';
import 'package:stridequest/features/runs/domain/services/health_sync.dart';
import 'package:stridequest/features/runs/domain/usecases/get_health_notice.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_notice_bloc.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_sheets.dart';

import '../../../../helpers/challenge_fixtures.dart';
import '../../../../helpers/health_fixtures.dart';
import '../../../../helpers/pump_screen.dart';

class _MockGetNotice extends Mock implements GetHealthNotice {}

class _MockSync extends Mock implements HealthSync {}

final _now = DateTime.utc(2026, 10, 17, 12);

void main() {
  late FakeChallengeRepository challenges;
  late FakeHealthRepository health;
  late _MockGetNotice getNotice;
  late _MockSync sync;

  setUp(() {
    challenges = FakeChallengeRepository(items: [summary()])
      ..detail = challenge()
      ..onAction = ((action, id) => challenge(enrollment: enrolled()));
    health = FakeHealthRepository(const HealthAccess.denied());
    getNotice = _MockGetNotice();
    sync = _MockSync();
    when(
      () => getNotice(clock: any(named: 'clock')),
    ).thenAnswer((_) async => HealthNotice.askable);
    when(() => sync.syncNow()).thenAnswer((_) async {});
    getIt
      ..registerFactory<ChallengesBloc>(() => ChallengesBloc(challenges))
      ..registerFactory<ChallengeDetailBloc>(
        () => ChallengeDetailBloc(challenges),
      )
      ..registerSingleton<GetHealthNotice>(getNotice)
      ..registerSingleton<HealthRepository>(health)
      ..registerFactory<HealthNoticeBloc>(
        () => HealthNoticeBloc(getNotice, health, sync),
      );
    addTearDown(getIt.reset);
  });

  // The two entry points: a card on the list, and the detail screen.
  final entries = <String, ({Widget Function() page, String join})>{
    'a card on the list': (
      page: () => BlocProvider(
        create: (_) => getIt<ChallengesBloc>()..add(const ChallengesStarted()),
        child: const ChallengesPage(),
      ),
      join: 'Join',
    ),
    'the detail screen': (
      page: () => BlocProvider(
        create: (_) =>
            getIt<ChallengeDetailBloc>()..add(const ChallengeDetailStarted(1)),
        child: ChallengeDetailPage(challengeId: 1, clock: () => _now),
      ),
      join: 'Join Challenge',
    ),
  };

  for (final MapEntry(key: name, value: entry) in entries.entries) {
    group('joining from $name', () {
      Future<void> join(WidgetTester tester) async {
        await pumpScreen(tester, entry.page());
        await tester.tap(find.widgetWithText(FilledButton, entry.join));
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

      testWidgets('a refused join opens nothing', (tester) async {
        await pumpScreen(tester, entry.page());
        challenges.failure = const ChallengeFailure(
          ChallengeFailureCode.challengeEnded,
        );
        await tester.tap(find.widgetWithText(FilledButton, entry.join));
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

      testWidgets('the join is unaffected when the health check throws', (
        tester,
      ) async {
        when(
          () => getNotice(clock: any(named: 'clock')),
        ).thenAnswer((_) async => throw StateError('no health'));
        final reported = <Object>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) => reported.add(details.exception);
        addTearDown(() => FlutterError.onError = previous);

        await join(tester);

        expect(find.text('Joined'), findsOneWidget);
        expect(find.byType(HealthExplainerSheet), findsNothing);
        expect(reported, [isA<StateError>()]);
      });
    });
  }
}

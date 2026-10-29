import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/core/router/app_router.dart';
import 'package:stridequest/core/router/go_router_refresh_stream.dart';
import 'package:stridequest/core/theme/app_theme.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';

import '../../../helpers/challenge_fixtures.dart';
import '../../../helpers/challenges_di.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Browse, search, filter and open a challenge through the real routes and
/// blocs, with an in-memory repository.
void main() {
  late FakeChallengeRepository repository;
  late AuthBloc authBloc;
  late GoRouterRefreshStream refresh;
  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    repository = FakeChallengeRepository(
      items: [
        summary(),
        summary(id: 2, title: 'Mỹ Khê Bay 20 km', type: ChallengeType.swim),
        summary(id: 3, title: 'Saigon Ride', type: ChallengeType.cycle),
      ],
    );
    repository.detail = challenge(id: 2, title: 'Mỹ Khê Bay 20 km');
    registerChallengeBlocs(repository);
    addTearDown(getIt.reset);

    final auth = _MockAuthRepository();
    when(() => auth.sessionStarted).thenAnswer((_) => const Stream.empty());
    when(() => auth.userUpdated).thenAnswer((_) => const Stream.empty());
    when(() => auth.accountDeleted).thenAnswer((_) => const Stream.empty());
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    when(() => auth.restoreSession()).thenAnswer(
      (_) async => AuthUser(
        id: 'user-1',
        email: 'runner@example.com',
        displayName: 'Lan Runner',
        createdAt: DateTime.utc(2026, 10, 13),
      ),
    );
    authBloc = AuthBloc(auth)..add(const AuthStarted());
    refresh = GoRouterRefreshStream(authBloc.stream);
    router = createAppRouter(authBloc: authBloc, refreshListenable: refresh);
    addTearDown(() async {
      router.dispose();
      refresh.dispose();
      await authBloc.close();
    });

    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(430, 932);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the tab lists the challenges', (tester) async {
    await pumpApp(tester);

    expect(find.text('Old Quarter 50K Steps'), findsOneWidget);
    expect(find.text('Mỹ Khê Bay 20 km'), findsOneWidget);
    expect(find.text('Saigon Ride'), findsOneWidget);
  });

  testWidgets('a type chip narrows the list', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Swim'));
    await tester.pumpAndSettle();

    expect(find.text('Mỹ Khê Bay 20 km'), findsOneWidget);
    expect(find.text('Old Quarter 50K Steps'), findsNothing);
    expect(repository.calls.last.type, ChallengeType.swim);
  });

  testWidgets('searching narrows the list after a pause', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'ride');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Saigon Ride'), findsOneWidget);
    expect(find.text('Mỹ Khê Bay 20 km'), findsNothing);
  });

  testWidgets('tapping a card opens its detail and back returns', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Mỹ Khê Bay 20 km'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/challenges/2');
    expect(find.text('Solo'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/challenges');
    expect(find.text('Saigon Ride'), findsOneWidget);
  });

  testWidgets('a detail that cannot load shows the error and retries', (
    tester,
  ) async {
    await pumpApp(tester);
    repository.failure = const ChallengeFailure(
      ChallengeFailureCode.challengeNotFound,
    );
    unawaited(router.push('/challenges/9'));
    await tester.pumpAndSettle();

    expect(find.text('This challenge is not available.'), findsOneWidget);

    repository.failure = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('This challenge is not available.'), findsNothing);
    expect(find.text('Solo'), findsOneWidget);
  });

  test('a signed-out user cannot open a challenge', () {
    expect(
      authRedirect(
        const AuthUnauthenticated(),
        location: '/challenges/2',
        route: '/challenges/:id',
        protected: protectedPaths,
      ),
      '/sign-in',
    );
  });

  group('joining', () {
    // The fake backend: remembers the caller's place in the challenge.
    Enrollment? place;
    Challenge answer(String action, int id) {
      place = switch (action) {
        'join' => enrolled(),
        'pause' => enrolled(EnrollmentStatus.paused),
        'resume' => enrolled(),
        _ => null,
      };
      return challenge(id: id, enrollment: place);
    }

    setUp(() => place = null);

    testWidgets('join, pause, resume and leave from the detail', (
      tester,
    ) async {
      await pumpApp(tester);
      repository.onAction = answer;
      await tester.tap(find.text('Mỹ Khê Bay 20 km'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Join Challenge'));
      await tester.pumpAndSettle();
      expect(find.text('Joined'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(find.text('Joined'), findsOneWidget);

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Leave this challenge?'), findsOneWidget);
      await tester.tap(find.text('Leave challenge'));
      await tester.pumpAndSettle();

      expect(find.text('Join Challenge'), findsOneWidget);
      expect(find.text('Joined'), findsNothing);
      expect(repository.actions, ['join 2', 'pause 2', 'resume 2', 'leave 2']);
    });

    testWidgets('keeping the challenge at the Leave question leaves nothing', (
      tester,
    ) async {
      await pumpApp(tester);
      repository.onAction = answer;
      await tester.tap(find.text('Mỹ Khê Bay 20 km'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Challenge'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(find.text('Joined'), findsOneWidget);
      expect(repository.actions, ['join 2']);
    });

    testWidgets('Joined shows on the card after coming back', (tester) async {
      await pumpApp(tester);
      repository.onAction = answer;
      await tester.tap(find.text('Mỹ Khê Bay 20 km'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Challenge'));
      await tester.pumpAndSettle();
      // The list now answers with the joined card.
      repository.items = [
        for (final item in repository.items)
          if (item.id == 2)
            summary(id: 2, title: 'Mỹ Khê Bay 20 km', enrollment: enrolled())
          else
            item,
      ];

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Joined'), findsOneWidget);
    });

    testWidgets('Join on a card joins and the card turns into Joined', (
      tester,
    ) async {
      await pumpApp(tester);
      repository.onAction = answer;

      await tester.tap(find.widgetWithText(FilledButton, 'Join').first);
      await tester.pumpAndSettle();

      expect(repository.actions, ['join 1']);
      expect(find.text('Joined'), findsOneWidget);
    });

    testWidgets('a refused join on a card says why', (tester) async {
      await pumpApp(tester);
      repository.failure = const ChallengeFailure(
        ChallengeFailureCode.overlappingChallenge,
        serverMessage: 'You are already in “Old Quarter 50K Steps”.',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Join').first);
      await tester.pumpAndSettle();

      expect(
        find.text('You are already in “Old Quarter 50K Steps”.'),
        findsOneWidget,
      );
    });

    testWidgets('a refused join on the detail says why and refreshes', (
      tester,
    ) async {
      await pumpApp(tester);
      repository.onAction = (action, id) => throw const ChallengeFailure(
        ChallengeFailureCode.overlappingChallenge,
        serverMessage: 'You are already in “Old Quarter 50K Steps”.',
      );
      await tester.tap(find.text('Mỹ Khê Bay 20 km'));
      await tester.pumpAndSettle();
      repository.detail = challenge(
        id: 2,
        title: 'Mỹ Khê Bay 20 km',
        blockedBy: const BlockingChallenge(
          id: 1,
          title: 'Old Quarter 50K Steps',
        ),
      );

      await tester.tap(find.text('Join Challenge'));
      await tester.pumpAndSettle();

      // The snackbar and the reason above the disabled button.
      expect(
        find.text('You are already in “Old Quarter 50K Steps”.'),
        findsOneWidget,
      );
      expect(find.textContaining('Finish, pause or leave it'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Join Challenge'),
            )
            .onPressed,
        isNull,
      );
    });
  });
}

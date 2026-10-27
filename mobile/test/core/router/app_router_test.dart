import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/core/router/app_router.dart';
import 'package:stridequest/core/router/go_router_refresh_stream.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenges_page.dart';

import '../../helpers/auth_di.dart';
import '../../helpers/auth_fixtures.dart';

class _MockRepository extends Mock implements AuthRepository {}

const _runsPath = '/runs';
const _challengePath = '/quests/:id';

/// The app routes plus protected routes, since the app has none yet: a static
/// one, and one with a path parameter and a nested child.
final _routes = [
  ...appRoutes,
  GoRoute(
    path: _runsPath,
    builder: (context, state) => const Scaffold(body: Text('Runs page')),
  ),
  GoRoute(
    path: _challengePath,
    builder: (context, state) =>
        Scaffold(body: Text('Challenge ${state.pathParameters['id']}')),
    routes: [
      GoRoute(
        path: 'edit',
        builder: (context, state) =>
            Scaffold(body: Text('Edit ${state.pathParameters['id']}')),
      ),
    ],
  ),
];

void main() {
  late _MockRepository repository;
  late StreamController<void> sessionExpired;
  late AuthBloc bloc;

  Future<void> pumpRouter(
    WidgetTester tester, {
    required bool signedIn,
    required String at,
    Duration restoreDelay = Duration.zero,
    Set<String> protected = const {_runsPath, _challengePath},
  }) async {
    when(() => repository.restoreSession()).thenAnswer((_) async {
      // A real secure-storage read finishes after the first redirect.
      await Future<void>.delayed(restoreDelay);
      return signedIn ? testUser.toEntity() : null;
    });
    bloc = AuthBloc(repository)..add(const AuthStarted());
    final authChanges = GoRouterRefreshStream(bloc.stream);
    final router = createAppRouter(
      authBloc: bloc,
      refreshListenable: authChanges,
      routes: _routes,
      protected: protected,
      initialLocation: at,
    );
    addTearDown(() {
      router.dispose();
      authChanges.dispose();
    });
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(restoreDelay);
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockRepository();
    sessionExpired = StreamController<void>.broadcast();
    when(
      () => repository.sessionExpired,
    ).thenAnswer((_) => sessionExpired.stream);
    when(
      () => repository.userUpdated,
    ).thenAnswer((_) => const Stream<AuthUser>.empty());
    when(
      () => repository.sessionStarted,
    ).thenAnswer((_) => const Stream<AuthUser>.empty());
    registerAuthFormBlocs(repository);
    addTearDown(getIt.reset);
    when(() => repository.signOut()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await bloc.close();
    await sessionExpired.close();
  });

  testWidgets('a signed-in user sees a protected page', (tester) async {
    await pumpRouter(tester, signedIn: true, at: _runsPath);

    expect(find.text('Runs page'), findsOneWidget);
  });

  testWidgets('signing out redirects to sign in', (tester) async {
    await pumpRouter(tester, signedIn: true, at: _runsPath);

    bloc.add(const AuthSignOutRequested());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Runs page'), findsNothing);
  });

  testWidgets('an expired session redirects to sign in', (tester) async {
    await pumpRouter(tester, signedIn: true, at: _runsPath);

    sessionExpired.add(null);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a signed-out user cannot open a protected page', (tester) async {
    await pumpRouter(tester, signedIn: false, at: _runsPath);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Runs page'), findsNothing);
  });

  testWidgets('a deep link to a protected page survives a slow session '
      'restore', (tester) async {
    await pumpRouter(
      tester,
      signedIn: true,
      at: _runsPath,
      restoreDelay: const Duration(milliseconds: 50),
    );

    expect(find.text('Runs page'), findsOneWidget);
  });

  testWidgets('a slow restore without a session still ends on sign in', (
    tester,
  ) async {
    await pumpRouter(
      tester,
      signedIn: false,
      at: _runsPath,
      restoreDelay: const Duration(milliseconds: 50),
    );

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a signed-out user cannot open a protected page with a path '
      'parameter', (tester) async {
    await pumpRouter(tester, signedIn: false, at: '/quests/abc');

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Challenge abc'), findsNothing);
  });

  testWidgets('a signed-in user sees a protected page with a path parameter', (
    tester,
  ) async {
    await pumpRouter(tester, signedIn: true, at: '/quests/abc');

    expect(find.text('Challenge abc'), findsOneWidget);
  });

  testWidgets('a deep link with a path parameter survives a slow session '
      'restore', (tester) async {
    await pumpRouter(
      tester,
      signedIn: true,
      at: '/quests/abc',
      restoreDelay: const Duration(milliseconds: 50),
    );

    expect(find.text('Challenge abc'), findsOneWidget);
  });

  testWidgets('a route nested under a protected route is protected', (
    tester,
  ) async {
    await pumpRouter(tester, signedIn: false, at: '/quests/abc/edit');

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Edit abc'), findsNothing);
  });

  group('with the app\'s own protected routes', () {
    testWidgets('a signed-out user on Home starts on sign in', (tester) async {
      await pumpRouter(
        tester,
        signedIn: false,
        at: '/',
        protected: protectedPaths,
      );

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(ChallengesPage), findsNothing);
    });

    testWidgets('a signed-in user on / lands on the Challenges tab', (
      tester,
    ) async {
      await pumpRouter(
        tester,
        signedIn: true,
        at: '/',
        protected: protectedPaths,
      );

      expect(find.byType(ChallengesPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('the tabs switch pages and keep the bar', (tester) async {
      await pumpRouter(
        tester,
        signedIn: true,
        at: '/',
        protected: protectedPaths,
      );

      for (final (label, title) in [
        ('Active', 'Active'),
        ('Medals', 'Medals'),
        ('Profile', 'Profile'),
        ('Challenges', 'Challenges'),
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();

        // The Active page has two tabs, and one of them is also called Active.
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text(title)),
          title == 'Active' ? findsNWidgets(2) : findsOneWidget,
        );
        expect(find.byType(NavigationBar), findsOneWidget);
      }
    });

    testWidgets('Sign in and Sign up have no tab bar', (tester) async {
      await pumpRouter(
        tester,
        signedIn: false,
        at: '/sign-up',
        protected: protectedPaths,
      );

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('every tab route is protected', (tester) async {
      for (final path in ['/challenges', '/active', '/medals', '/profile']) {
        await pumpRouter(
          tester,
          signedIn: false,
          at: path,
          protected: protectedPaths,
        );

        expect(find.text('Welcome back'), findsOneWidget, reason: path);
        expect(find.byType(NavigationBar), findsNothing, reason: path);
      }
    });

    testWidgets('Home never shows its content while the session is read', (
      tester,
    ) async {
      when(() => repository.restoreSession()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return null;
      });
      bloc = AuthBloc(repository)..add(const AuthStarted());
      final authChanges = GoRouterRefreshStream(bloc.stream);
      final router = createAppRouter(
        authBloc: bloc,
        refreshListenable: authChanges,
      );
      addTearDown(() {
        router.dispose();
        authChanges.dispose();
      });
      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: bloc,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(ChallengesPage), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  testWidgets('a signed-in user on sign in goes to the first tab', (
    tester,
  ) async {
    await pumpRouter(tester, signedIn: true, at: '/sign-in');

    expect(find.byType(ChallengesPage), findsOneWidget);
  });

  testWidgets('a signed-in user on sign up goes to the first tab', (
    tester,
  ) async {
    await pumpRouter(tester, signedIn: true, at: '/sign-up');

    expect(find.byType(ChallengesPage), findsOneWidget);
  });

  testWidgets('a signed-out user can open sign up', (tester) async {
    await pumpRouter(tester, signedIn: false, at: '/sign-up');

    expect(find.text('Create your account'), findsOneWidget);
  });

  group('isProtectedRoute', () {
    const protected = {'/challenges'};

    test('matches the pattern and routes nested under it', () {
      expect(isProtectedRoute('/challenges', protected), isTrue);
      expect(isProtectedRoute('/challenges/:id', protected), isTrue);
    });

    test('does not match a sibling that shares a prefix', () {
      expect(isProtectedRoute('/challenges-archive', protected), isFalse);
    });

    test('does not match an unmatched location', () {
      expect(isProtectedRoute(null, protected), isFalse);
    });
  });
}

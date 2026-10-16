import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/router/app_router.dart';
import 'package:stridequest/core/router/go_router_refresh_stream.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';

import '../../helpers/auth_fixtures.dart';

class _MockRepository extends Mock implements AuthRepository {}

const _runsPath = '/runs';

/// The app routes plus one protected route, since the app has none yet.
final _routes = [
  ...appRoutes,
  GoRoute(
    path: _runsPath,
    builder: (context, state) => const Scaffold(body: Text('Runs page')),
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
      protected: const {_runsPath},
      initialLocation: at,
    );
    addTearDown(() {
      router.dispose();
      authChanges.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(restoreDelay);
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _MockRepository();
    sessionExpired = StreamController<void>.broadcast();
    when(
      () => repository.sessionExpired,
    ).thenAnswer((_) => sessionExpired.stream);
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

    expect(find.text('Sign in to continue.'), findsOneWidget);
    expect(find.text('Runs page'), findsNothing);
  });

  testWidgets('an expired session redirects to sign in', (tester) async {
    await pumpRouter(tester, signedIn: true, at: _runsPath);

    sessionExpired.add(null);
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue.'), findsOneWidget);
  });

  testWidgets('a signed-out user cannot open a protected page', (tester) async {
    await pumpRouter(tester, signedIn: false, at: _runsPath);

    expect(find.text('Sign in to continue.'), findsOneWidget);
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

    expect(find.text('Sign in to continue.'), findsOneWidget);
  });

  testWidgets('home stays public', (tester) async {
    await pumpRouter(tester, signedIn: false, at: '/');

    expect(find.text('Every run is a quest.'), findsOneWidget);
  });

  testWidgets('a signed-in user on sign in goes home', (tester) async {
    await pumpRouter(tester, signedIn: true, at: '/sign-in');

    expect(find.text('Every run is a quest.'), findsOneWidget);
  });
}

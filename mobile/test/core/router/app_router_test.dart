import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/router/app_router.dart';
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
  }) async {
    when(
      () => repository.restoreSession(),
    ).thenAnswer((_) async => signedIn ? testUser.toEntity() : null);
    bloc = AuthBloc(repository)..add(const AuthStarted());
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: createAppRouter(
          authBloc: bloc,
          routes: _routes,
          protected: const {_runsPath},
          initialLocation: at,
        ),
      ),
    );
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

  testWidgets('home stays public', (tester) async {
    await pumpRouter(tester, signedIn: false, at: '/');

    expect(find.text('Every run is a quest.'), findsOneWidget);
  });

  testWidgets('a signed-in user on sign in goes home', (tester) async {
    await pumpRouter(tester, signedIn: true, at: '/sign-in');

    expect(find.text('Every run is a quest.'), findsOneWidget);
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/core/router/app_router.dart';
import 'package:stridequest/core/theme/app_theme.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_email_bloc.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_password_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_in_page.dart';
import 'package:stridequest/features/home/presentation/pages/home_shell.dart';
import 'package:stridequest/features/profile/data/datasources/fake_profile_remote_data_source.dart';
import 'package:stridequest/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:stridequest/features/profile/presentation/bloc/profile_info_bloc.dart';
import 'package:stridequest/features/profile/presentation/pages/profile_page.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/mock_auth_bloc.dart';
import '../../../../helpers/pump_screen.dart';

final _user = AuthUser(
  id: 'user-1',
  email: 'runner@example.com',
  displayName: 'Lan Runner',
  createdAt: DateTime.utc(2026, 10, 13, 9, 55),
);

/// The Profile tab inside a shell with the tab bar, with the real account
/// routes above the shell, as in the app.
Widget _routerApp(MockAuthBloc bloc) {
  final router = GoRouter(
    initialLocation: ProfilePage.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProfilePage.path,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      ...appRoutes.whereType<GoRoute>().where(
        (r) => r.path.startsWith('/profile/'),
      ),
    ],
  );
  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

void main() {
  late MockAuthBloc bloc;

  setUpAll(() => registerFallbackValue(const AuthStarted()));
  setUp(() {
    bloc = MockAuthBloc();
    // The account routes build their blocs from `getIt`.
    final auth = MockAuthRepository();
    when(auth.restoreSession).thenAnswer((_) async => _user);
    getIt
      ..registerFactory<ChangeEmailBloc>(() => ChangeEmailBloc(auth))
      ..registerFactory<ChangePasswordBloc>(() => ChangePasswordBloc(auth));
    getIt.registerFactory<ProfileInfoBloc>(
      () =>
          ProfileInfoBloc(ProfileRepositoryImpl(FakeProfileRemoteDataSource())),
    );
  });
  tearDown(getIt.reset);

  Future<void> pumpProfile(
    WidgetTester tester, {
    AuthState? state,
    Size size = smallPhone,
    double textScale = 1,
  }) async {
    whenListen(
      bloc,
      const Stream<AuthState>.empty(),
      initialState: state ?? AuthAuthenticated(_user),
    );
    await pumpScreen(
      tester,
      BlocProvider<AuthBloc>.value(value: bloc, child: const ProfilePage()),
      size: size,
      textScale: textScale,
    );
  }

  testWidgets('shows the initials, the three rows and Sign out', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('LR'), findsOneWidget);
    expect(find.text('Change Avatar'), findsNothing);
    for (final row in ['Profile', 'Email', 'Password']) {
      expect(find.widgetWithText(ListTile, row), findsOneWidget);
    }
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('a one-word name gives one initial', (tester) async {
    await pumpProfile(
      tester,
      state: AuthAuthenticated(
        AuthUser(
          id: 'u',
          email: 'a@example.com',
          displayName: 'lan',
          createdAt: DateTime.utc(2026),
        ),
      ),
    );

    expect(find.text('L'), findsOneWidget);
  });

  testWidgets('an emoji first letter is kept whole', (tester) async {
    await pumpProfile(
      tester,
      state: AuthAuthenticated(
        AuthUser(
          id: 'u',
          email: 'a@example.com',
          displayName: '🏃 Lan',
          createdAt: DateTime.utc(2026),
        ),
      ),
    );

    expect(find.text('🏃L'), findsOneWidget);
  });

  testWidgets('a blank name falls back to the email letter', (tester) async {
    await pumpProfile(
      tester,
      state: AuthAuthenticated(
        AuthUser(
          id: 'u',
          email: 'runner@example.com',
          displayName: '  ',
          createdAt: DateTime.utc(2026),
        ),
      ),
    );

    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('Sign out sends the event', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));

    verify(() => bloc.add(const AuthSignOutRequested())).called(1);
  });

  testWidgets('shows no initials when nobody is signed in', (tester) async {
    await pumpProfile(tester, state: const AuthUnauthenticated());

    expect(find.text('LR'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
  });

  group('navigation', () {
    for (final (row, path) in [
      ('Profile', '/profile/info'),
      ('Email', '/profile/email'),
      ('Password', '/profile/password'),
    ]) {
      testWidgets('$row opens $path and back returns', (tester) async {
        whenListen(
          bloc,
          const Stream<AuthState>.empty(),
          initialState: AuthAuthenticated(_user),
        );
        await tester.pumpWidget(_routerApp(bloc));
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
        await tester.tap(find.widgetWithText(ListTile, row));
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsNothing);
        // Each row opens its own form.
        expect(
          find.text(switch (row) {
            'Profile' => 'First Name',
            'Email' => 'Email address',
            _ => 'Current Password',
          }),
          findsOneWidget,
        );
        expect(find.widgetWithText(AppBar, row), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Current Password'), findsNothing);
        expect(find.text('First Name'), findsNothing);
        expect(find.text('Email address'), findsNothing);
        expect(find.text('Sign out'), findsOneWidget);
      });
    }

    for (final path in [
      '/profile/info',
      '/profile/email',
      '/profile/password',
    ]) {
      test('$path sends a signed-out user to sign in', () {
        expect(
          authRedirect(
            const AuthUnauthenticated(),
            location: path,
            route: path,
            protected: protectedPaths,
          ),
          SignInPage.path,
        );
      });
    }
  });

  group('layout and accessibility', () {
    for (final size in [smallPhone, largePhone]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('fits and is accessible on $size at text x$textScale', (
          tester,
        ) async {
          await pumpProfile(tester, size: size, textScale: textScale);

          expectNoLayoutException(tester);
          await expectAccessible(tester);
        });
      }
    }
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/theme/app_theme.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_in_page.dart';
import 'package:stridequest/features/home/presentation/pages/home_page.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/mock_auth_bloc.dart';
import '../../../../helpers/pump_screen.dart';

final _user = AuthUser(
  id: 'user-1',
  email: 'runner@example.com',
  displayName: 'Lan Runner',
  createdAt: DateTime.utc(2026, 10, 13, 9, 55),
);

void main() {
  late MockAuthBloc bloc;

  setUpAll(() => registerFallbackValue(const AuthStarted()));
  setUp(() => bloc = MockAuthBloc());

  Future<void> pumpHome(
    WidgetTester tester,
    AuthState state, {
    Size size = smallPhone,
    double textScale = 1,
  }) async {
    whenListen(bloc, const Stream<AuthState>.empty(), initialState: state);
    await pumpScreen(
      tester,
      BlocProvider<AuthBloc>.value(value: bloc, child: const HomePage()),
      size: size,
      textScale: textScale,
    );
  }

  group('signed out', () {
    testWidgets('shows the title, the tagline and a Sign in action', (
      tester,
    ) async {
      await pumpHome(tester, const AuthUnauthenticated());

      expect(find.text('StrideQuest'), findsOneWidget);
      expect(find.text('Every run is a quest.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sign in'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('Sign in opens the sign-in page', (tester) async {
      whenListen(
        bloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthUnauthenticated(),
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: HomePage.path, builder: (_, _) => const HomePage()),
          GoRoute(path: SignInPage.path, builder: (_, _) => const SignInPage()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: bloc,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Every run is a quest.'), findsOneWidget);
    });

    testWidgets('the action is disabled while a sign in runs', (tester) async {
      await pumpHome(tester, const AuthInProgress());

      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
    });
  });

  group('signed in', () {
    testWidgets('greets the user by name and offers Sign out', (tester) async {
      await pumpHome(tester, AuthAuthenticated(_user));

      expect(find.text('Welcome back, Lan Runner.'), findsOneWidget);
      expect(find.text('Every run is a quest.'), findsOneWidget);
      expect(find.byTooltip('Sign out'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('Sign out sends the event', (tester) async {
      await pumpHome(tester, AuthAuthenticated(_user));

      await tester.tap(find.byTooltip('Sign out'));

      verify(() => bloc.add(const AuthSignOutRequested())).called(1);
    });
  });

  group('layout and accessibility', () {
    final states = <String, AuthState>{
      'signed out': const AuthUnauthenticated(),
      'signed in': AuthAuthenticated(_user),
    };
    for (final entry in states.entries) {
      for (final size in [smallPhone, largePhone]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '${entry.key} fits and is accessible on $size at text x$textScale',
            (tester) async {
              await pumpHome(
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
  });
}

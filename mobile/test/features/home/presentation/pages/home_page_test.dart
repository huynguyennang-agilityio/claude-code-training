import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
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
    bool settle = true,
  }) async {
    whenListen(bloc, const Stream<AuthState>.empty(), initialState: state);
    await pumpScreen(
      tester,
      BlocProvider<AuthBloc>.value(value: bloc, child: const HomePage()),
      size: size,
      textScale: textScale,
      settle: settle,
    );
  }

  group('not signed in', () {
    final states = <String, AuthState>{
      'reading the stored session': const AuthUnknown(),
      'signed out': const AuthUnauthenticated(),
      'signing in': const AuthInProgress(),
    };
    for (final entry in states.entries) {
      testWidgets('shows progress and no content while ${entry.key}', (
        tester,
      ) async {
        await pumpHome(tester, entry.value, settle: false);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Every run is a quest.'), findsNothing);
        expect(find.text('Sign in'), findsNothing);
        expect(find.byTooltip('Sign out'), findsNothing);
      });
    }
  });

  group('signed in', () {
    testWidgets('greets the user by name and offers Sign out', (tester) async {
      await pumpHome(tester, AuthAuthenticated(_user));

      expect(find.text('Welcome back, Lan Runner.'), findsOneWidget);
      expect(find.text('Every run is a quest.'), findsOneWidget);
      expect(find.byTooltip('Sign out'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('has no back button', (tester) async {
      await pumpHome(tester, AuthAuthenticated(_user));

      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('Sign out sends the event', (tester) async {
      await pumpHome(tester, AuthAuthenticated(_user));

      await tester.tap(find.byTooltip('Sign out'));

      verify(() => bloc.add(const AuthSignOutRequested())).called(1);
    });
  });

  group('layout and accessibility', () {
    final states = <String, AuthState>{'signed in': AuthAuthenticated(_user)};
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

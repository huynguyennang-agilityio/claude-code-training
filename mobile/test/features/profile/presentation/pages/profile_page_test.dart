import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/profile/presentation/pages/profile_page.dart';

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

  testWidgets('shows who is signed in', (tester) async {
    await pumpProfile(tester);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Lan Runner'), findsOneWidget);
    expect(find.text('runner@example.com'), findsOneWidget);
  });

  testWidgets('Sign out sends the event', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));

    verify(() => bloc.add(const AuthSignOutRequested())).called(1);
  });

  testWidgets('shows no account details when nobody is signed in', (
    tester,
  ) async {
    await pumpProfile(tester, state: const AuthUnauthenticated());

    expect(find.text('Lan Runner'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
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

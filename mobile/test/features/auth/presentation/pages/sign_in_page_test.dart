import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_in_page.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/mock_auth_bloc.dart';
import '../../../../helpers/pump_screen.dart';

void main() {
  late MockAuthBloc bloc;

  setUpAll(() => registerFallbackValue(const AuthStarted()));
  setUp(() => bloc = MockAuthBloc());

  Future<void> pumpPage(
    WidgetTester tester, {
    AuthState state = const AuthUnauthenticated(),
    Size size = smallPhone,
    double textScale = 1,
    bool settle = true,
  }) async {
    whenListen(bloc, const Stream<AuthState>.empty(), initialState: state);
    await pumpScreen(
      tester,
      BlocProvider<AuthBloc>.value(value: bloc, child: const SignInPage()),
      size: size,
      textScale: textScale,
      settle: settle,
    );
  }

  final email = find.widgetWithText(TextFormField, 'Email');
  final password = find.widgetWithText(TextFormField, 'Password');
  final signInButton = find.widgetWithText(FilledButton, 'Sign in');

  AuthUnauthenticated failed(
    AuthFailureCode code, {
    Map<String, String> fieldErrors = const {},
    Duration? retryAfter,
  }) => AuthUnauthenticated(
    failure: AuthFailure(
      code,
      fieldErrors: fieldErrors,
      retryAfter: retryAfter,
    ),
  );

  group('initial state', () {
    testWidgets('shows the form and no message', (tester) async {
      await pumpPage(tester);

      expect(find.text('Welcome back'), findsOneWidget);
      expect(email, findsOneWidget);
      expect(password, findsOneWidget);
      expect(signInButton, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<FilledButton>(signInButton).onPressed, isNotNull);
    });
  });

  group('in progress', () {
    testWidgets('disables the form and shows a progress indicator', (
      tester,
    ) async {
      await pumpPage(tester, state: const AuthInProgress(), settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isFalse,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
  });

  group('failure', () {
    testWidgets('shows the failure message in a live region', (tester) async {
      await pumpPage(tester, state: failed(AuthFailureCode.invalidCredentials));

      final message = AuthFailureCode.invalidCredentials.defaultMessage;
      expect(find.text(message), findsOneWidget);
      expect(
        tester.getSemantics(find.text(message)).flagsCollection.isLiveRegion,
        isTrue,
      );
    });

    testWidgets('shows a network failure', (tester) async {
      await pumpPage(tester, state: failed(AuthFailureCode.network));

      expect(find.text(AuthFailureCode.network.defaultMessage), findsOneWidget);
    });

    testWidgets('puts field messages under their fields', (tester) async {
      await pumpPage(
        tester,
        state: failed(
          AuthFailureCode.validation,
          fieldErrors: {
            'email': 'Enter a valid email address.',
            'password': 'Too short.',
          },
        ),
      );

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Too short.'), findsOneWidget);
    });

    testWidgets('clears a field message when that field is edited', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: failed(
          AuthFailureCode.validation,
          fieldErrors: {'email': 'Server says no.', 'password': 'Too short.'},
        ),
      );

      await tester.enterText(email, 'runner@example.com');
      await tester.pump();

      expect(find.text('Server says no.'), findsNothing);
      expect(find.text('Too short.'), findsOneWidget);
    });

    testWidgets('says how long to wait when rate limited', (tester) async {
      await pumpPage(
        tester,
        state: failed(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 14, seconds: 30),
        ),
      );

      expect(
        find.text(
          '${AuthFailureCode.rateLimited.defaultMessage} Try again in 15 minutes.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses the singular for a wait of up to one minute', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: failed(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(seconds: 30),
        ),
      );

      expect(find.textContaining('Try again in 1 minute.'), findsOneWidget);
    });

    testWidgets('shows only the message when no wait is known', (tester) async {
      await pumpPage(tester, state: failed(AuthFailureCode.rateLimited));

      expect(
        find.text(AuthFailureCode.rateLimited.defaultMessage),
        findsOneWidget,
      );
    });
  });

  group('session expired', () {
    testWidgets('explains why the user is here', (tester) async {
      await pumpPage(
        tester,
        state: const AuthUnauthenticated(sessionExpired: true),
      );

      expect(
        find.text('Your session has expired. Sign in again.'),
        findsOneWidget,
      );
    });
  });

  group('submitting', () {
    testWidgets('sends the trimmed email and the password as typed', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.enterText(email, '  runner@example.com ');
      await tester.enterText(password, ' run4medals ');
      await tester.tap(signInButton);
      await tester.pump();

      verify(
        () => bloc.add(
          const AuthSignInRequested(
            email: 'runner@example.com',
            password: ' run4medals ',
          ),
        ),
      ).called(1);
    });

    testWidgets('submits from the keyboard', (tester) async {
      await pumpPage(tester);

      await tester.enterText(email, 'runner@example.com');
      await tester.enterText(password, 'run4medals');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      verify(() => bloc.add(any(that: isA<AuthSignInRequested>()))).called(1);
    });

    testWidgets('asks for both fields and sends nothing when they are empty', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(signInButton);
      await tester.pump();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('rejects an email that is not shaped like an address', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.enterText(email, 'runner');
      await tester.enterText(password, 'run4medals');
      await tester.tap(signInButton);
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('does not check password rules', (tester) async {
      await pumpPage(tester);

      await tester.enterText(email, 'runner@example.com');
      await tester.enterText(password, 'x');
      await tester.tap(signInButton);
      await tester.pump();

      verify(() => bloc.add(any(that: isA<AuthSignInRequested>()))).called(1);
    });
  });

  group('password field', () {
    bool obscured(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText;

    testWidgets('is hidden until the toggle is pressed', (tester) async {
      await pumpPage(tester);
      expect(obscured(tester), isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(obscured(tester), isFalse);

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(obscured(tester), isTrue);
    });
  });

  group('layout and accessibility', () {
    final states = <String, AuthState>{
      'initial': const AuthUnauthenticated(),
      'invalid credentials': AuthUnauthenticated(
        failure: AuthFailure(AuthFailureCode.invalidCredentials),
      ),
      'rate limited': AuthUnauthenticated(
        failure: AuthFailure(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 15),
        ),
      ),
      'field errors': AuthUnauthenticated(
        failure: AuthFailure(
          AuthFailureCode.validation,
          fieldErrors: const {'email': 'Enter a valid email address.'},
        ),
      ),
    };

    for (final entry in states.entries) {
      for (final size in [smallPhone, largePhone]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '${entry.key} fits and is accessible on $size at text x$textScale',
            (tester) async {
              await pumpPage(
                tester,
                state: entry.value,
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

    testWidgets('scrolls when the keyboard takes the screen', (tester) async {
      await pumpPage(tester, size: const Size(375, 300), textScale: 2);

      expectNoLayoutException(tester);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}

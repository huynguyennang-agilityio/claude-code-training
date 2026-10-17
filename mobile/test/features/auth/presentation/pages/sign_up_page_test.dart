import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/pages/sign_up_page.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';

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
      BlocProvider<AuthBloc>.value(value: bloc, child: const SignUpPage()),
      size: size,
      textScale: textScale,
      settle: settle,
    );
  }

  final displayName = find.widgetWithText(AuthTextField, 'Display name');
  final email = find.widgetWithText(AuthTextField, 'Email');
  final password = find.widgetWithText(AuthTextField, 'Password');
  final createButton = find.widgetWithText(FilledButton, 'Create account');

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

  Future<void> fillValid(WidgetTester tester) async {
    await tester.enterText(displayName, '  Lan Runner ');
    await tester.enterText(email, '  lan@example.com ');
    await tester.enterText(password, 'run4medals');
  }

  group('initial state', () {
    testWidgets('shows the form and no message', (tester) async {
      await pumpPage(tester);

      expect(find.text('Create your account'), findsOneWidget);
      expect(
        find.text('Start your first quest in under a minute.'),
        findsOneWidget,
      );
      expect(find.text('How runners will see you'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.text('8–128 characters'), findsOneWidget);
      expect(
        find.text('Use at least one letter and one number.'),
        findsOneWidget,
      );
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('has no confirm-password field', (tester) async {
      await pumpPage(tester);

      expect(find.byType(AuthTextField), findsNWidgets(3));
    });
  });

  group('in progress', () {
    testWidgets('disables the fields and the button and shows progress', (
      tester,
    ) async {
      await pumpPage(tester, state: const AuthInProgress(), settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      for (final field in find.byType(TextField).evaluate()) {
        expect((field.widget as TextField).enabled, isFalse);
      }
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
  });

  group('failures', () {
    testWidgets('a taken email is shown on the email field, not a banner', (
      tester,
    ) async {
      await pumpPage(tester, state: failed(AuthFailureCode.emailTaken));

      expect(
        find.text(AuthFailureCode.emailTaken.defaultMessage),
        findsOneWidget,
      );
      // The message is the field's error text, so it is not announced twice.
      expect(find.byType(Semantics).evaluate().where(_isLiveRegion), isEmpty);
    });

    testWidgets('a taken email clears when the email is edited', (
      tester,
    ) async {
      await pumpPage(tester, state: failed(AuthFailureCode.emailTaken));

      await tester.enterText(email, 'other@example.com');
      await tester.pump();

      expect(
        find.text(AuthFailureCode.emailTaken.defaultMessage),
        findsNothing,
      );
    });

    testWidgets('shows server field messages under their fields', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: failed(
          AuthFailureCode.validation,
          fieldErrors: const {
            'display_name': 'Too long.',
            'email': 'Bad email.',
            'password': 'Too weak.',
          },
        ),
      );

      expect(find.text('Too long.'), findsOneWidget);
      expect(find.text('Bad email.'), findsOneWidget);
      expect(find.text('Too weak.'), findsOneWidget);
      expect(find.text('Check the highlighted fields.'), findsOneWidget);
    });

    testWidgets('a field message clears when that field is edited', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: failed(
          AuthFailureCode.validation,
          fieldErrors: const {'password': 'Too weak.', 'email': 'Bad email.'},
        ),
      );

      await tester.enterText(password, 'better1234');
      // The old message fades out of the field before it is gone.
      await tester.pumpAndSettle();

      expect(find.text('Too weak.'), findsNothing);
      expect(find.text('Bad email.'), findsOneWidget);
    });

    testWidgets('rate limited says how long to wait', (tester) async {
      await pumpPage(
        tester,
        state: failed(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 15),
        ),
      );

      expect(find.textContaining('Try again in 15 minutes.'), findsOneWidget);
    });

    testWidgets('a network failure shows its message in the banner', (
      tester,
    ) async {
      await pumpPage(tester, state: failed(AuthFailureCode.network));

      expect(find.text(AuthFailureCode.network.defaultMessage), findsOneWidget);
    });
  });

  group('submitting', () {
    testWidgets('sends the trimmed name and email and the password as typed', (
      tester,
    ) async {
      await pumpPage(tester);

      await fillValid(tester);
      await tester.tap(createButton);
      await tester.pump();

      verify(
        () => bloc.add(
          const AuthSignUpRequested(
            email: 'lan@example.com',
            password: 'run4medals',
            displayName: 'Lan Runner',
          ),
        ),
      ).called(1);
    });

    testWidgets('submits from the keyboard', (tester) async {
      await pumpPage(tester);

      await fillValid(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      verify(() => bloc.add(any(that: isA<AuthSignUpRequested>()))).called(1);
    });

    testWidgets('asks for every field and sends nothing when they are empty', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter a password.'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('rejects a name that is only spaces', (tester) async {
      await pumpPage(tester);

      await tester.enterText(displayName, '   ');
      await tester.enterText(email, 'lan@example.com');
      await tester.enterText(password, 'run4medals');
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('Enter a name.'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('rejects a name longer than 50 characters', (tester) async {
      await pumpPage(tester);

      await tester.enterText(displayName, 'a' * 51);
      await tester.enterText(email, 'lan@example.com');
      await tester.enterText(password, 'run4medals');
      await tester.tap(createButton);
      await tester.pump();

      expect(
        find.text('Use up to 50 characters, with no control characters.'),
        findsOneWidget,
      );
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('accepts a name of exactly 50 characters', (tester) async {
      await pumpPage(tester);

      await tester.enterText(displayName, 'a' * 50);
      await tester.enterText(email, 'lan@example.com');
      await tester.enterText(password, 'run4medals');
      await tester.tap(createButton);
      await tester.pump();

      verify(() => bloc.add(any(that: isA<AuthSignUpRequested>()))).called(1);
    });

    testWidgets('rejects an email that is not shaped like an address', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.enterText(displayName, 'Lan');
      await tester.enterText(email, 'lan');
      await tester.enterText(password, 'run4medals');
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    final weakPasswords = {
      'too short': 'run4it',
      'no digit': 'runnerrunner',
      'no letter': '123456789',
      'too long': 'a1${'b' * 127}',
    };
    for (final entry in weakPasswords.entries) {
      testWidgets('rejects a password that is ${entry.key}', (tester) async {
        await pumpPage(tester);

        await tester.enterText(displayName, 'Lan');
        await tester.enterText(email, 'lan@example.com');
        await tester.enterText(password, entry.value);
        await tester.tap(createButton);
        await tester.pump();

        expect(
          find.text('Use 8–128 characters with a letter and a number.'),
          findsOneWidget,
        );
        verifyNever(() => bloc.add(any()));
      });
    }

    testWidgets('accepts passwords of 8 and 128 characters', (tester) async {
      for (final value in ['a1234567', 'a1${'b' * 126}']) {
        await pumpPage(tester);
        await tester.enterText(displayName, 'Lan');
        await tester.enterText(email, 'lan@example.com');
        await tester.enterText(password, value);
        await tester.tap(createButton);
        await tester.pump();
      }

      verify(() => bloc.add(any(that: isA<AuthSignUpRequested>()))).called(2);
    });
  });

  group('password field', () {
    bool obscured(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText;

    testWidgets('is hidden until the toggle is pressed', (tester) async {
      await pumpPage(tester);
      expect(obscured(tester), isTrue);

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(obscured(tester), isFalse);

      await tester.tap(find.text('Hide'));
      await tester.pump();
      expect(obscured(tester), isTrue);
    });
  });

  group('layout and accessibility', () {
    final states = <String, AuthState>{
      'initial': const AuthUnauthenticated(),
      'email taken': failed(AuthFailureCode.emailTaken),
      'field errors': failed(
        AuthFailureCode.validation,
        fieldErrors: const {
          'display_name': 'Display name must be 1 to 50 characters.',
          'email': 'Enter a valid email address.',
          'password':
              'Password must be 8 to 128 characters with a letter and a digit.',
        },
      ),
      'rate limited': failed(
        AuthFailureCode.rateLimited,
        retryAfter: const Duration(minutes: 15),
      ),
    };

    for (final entry in states.entries) {
      for (final size in [smallPhone, largePhone]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '${entry.key} fits and is accessible on $size at text x$scale',
            (tester) async {
              await pumpPage(
                tester,
                state: entry.value,
                size: size,
                textScale: scale,
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
      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });
}

bool _isLiveRegion(Element element) {
  final widget = element.widget;
  return widget is Semantics && (widget.properties.liveRegion ?? false);
}

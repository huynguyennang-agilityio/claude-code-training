import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/auth/data/datasources/fake_auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/models/auth_session_model.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';

void main() {
  late FakeAuthRemoteDataSource repository;

  setUp(() => repository = FakeAuthRemoteDataSource());

  test('signs up, then signs in with the same email in any case', () async {
    final created = await repository.signUp(
      email: 'Runner@Example.com',
      password: 'run4medals',
      displayName: 'Lan Runner',
    );

    final session = await repository.signIn(
      email: 'runner@example.com',
      password: 'run4medals',
    );

    expect(session.user, created.user);
    expect(session.user.email, 'runner@example.com');
  });

  test('rejects a second sign up with the same email', () async {
    await repository.signUp(
      email: 'runner@example.com',
      password: 'run4medals',
      displayName: 'Lan',
    );

    expect(
      () => repository.signUp(
        email: 'runner@example.com',
        password: 'run4medals',
        displayName: 'Lan',
      ),
      throwsA(
        isA<AuthFailure>().having(
          (f) => f.code,
          'code',
          AuthFailureCode.emailTaken,
        ),
      ),
    );
  });

  test('checks the contract field rules before duplicates', () async {
    await repository.signUp(
      email: 'runner@example.com',
      password: 'run4medals',
      displayName: 'Lan',
    );

    final failure = await repository
        .signUp(
          email: 'runner@example.com',
          password: 'onlyletters',
          displayName: '   ',
        )
        .then<AuthFailure?>(
          (_) => null,
          onError: (Object e) => e as AuthFailure,
        );

    expect(failure?.code, AuthFailureCode.validation);
    expect(
      failure?.fieldErrors.keys,
      unorderedEquals(['password', 'display_name']),
    );
  });

  test('rejects an invalid email', () async {
    final failure = await repository
        .signUp(
          email: 'not-an-email',
          password: 'run4medals',
          displayName: 'Lan',
        )
        .then<AuthFailure?>(
          (_) => null,
          onError: (Object e) => e as AuthFailure,
        );

    expect(failure?.fieldErrors.keys, ['email']);
  });

  test('rejects a wrong password', () async {
    await repository.signUp(
      email: 'runner@example.com',
      password: 'run4medals',
      displayName: 'Lan',
    );

    expect(
      () =>
          repository.signIn(email: 'runner@example.com', password: 'nope1234'),
      throwsA(
        isA<AuthFailure>().having(
          (f) => f.code,
          'code',
          AuthFailureCode.invalidCredentials,
        ),
      ),
    );
  });

  test('rotates refresh tokens and rejects a used one', () async {
    final session = await repository.signUp(
      email: 'runner@example.com',
      password: 'run4medals',
      displayName: 'Lan',
    );

    final refreshed = await repository.refresh(session.tokens.refreshToken);

    expect(refreshed.refreshToken, isNot(session.tokens.refreshToken));
    expect(
      () => repository.refresh(session.tokens.refreshToken),
      throwsA(
        isA<AuthFailure>().having(
          (f) => f.code,
          'code',
          AuthFailureCode.invalidRefreshToken,
        ),
      ),
    );
  });

  test('sign out revokes the refresh token', () async {
    final session = await repository.signUp(
      email: 'runner@example.com',
      password: 'run4medals',
      displayName: 'Lan',
    );

    await repository.signOut(session.tokens.refreshToken);

    expect(
      () => repository.refresh(session.tokens.refreshToken),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('issues tokens with the contract access token lifetime', () async {
    final session = await repository.signUp(
      email: 'runner@example.com',
      password: 'run4medals',
      displayName: 'Lan',
    );

    expect(session.tokens.expiresIn, const Duration(minutes: 15));
  });

  test('rejects a malformed sign in body with validation_error', () async {
    final failure = repository.signIn(email: 'not-an-email', password: '');

    await expectLater(
      failure,
      throwsA(
        isA<AuthFailure>()
            .having((f) => f.code, 'code', AuthFailureCode.validation)
            .having((f) => f.fieldErrors.keys, 'fields', ['email', 'password']),
      ),
    );
  });

  group('sign in rate limit', () {
    late DateTime now;

    setUp(() async {
      now = DateTime.utc(2026, 10, 14, 9);
      repository = FakeAuthRemoteDataSource(now: () => now);
      await repository.signUp(
        email: 'runner@example.com',
        password: 'run4medals',
        displayName: 'Lan',
      );
    });

    Future<void> failSignIns(int times) async {
      for (var i = 0; i < times; i++) {
        await expectLater(
          repository.signIn(email: 'runner@example.com', password: 'wrong123'),
          throwsA(isA<AuthFailure>()),
        );
      }
    }

    test('blocks even the right password after 5 failures', () async {
      await failSignIns(FakeAuthRemoteDataSource.maxFailedSignIns);
      now = now.add(const Duration(minutes: 5));

      await expectLater(
        repository.signIn(email: 'runner@example.com', password: 'run4medals'),
        throwsA(
          isA<AuthFailure>()
              .having((f) => f.code, 'code', AuthFailureCode.rateLimited)
              .having(
                (f) => f.retryAfter,
                'retryAfter',
                const Duration(minutes: 10),
              ),
        ),
      );
    });

    test('allows sign in again once the window passes', () async {
      await failSignIns(FakeAuthRemoteDataSource.maxFailedSignIns);
      now = now.add(FakeAuthRemoteDataSource.signInFailureWindow);

      final session = await repository.signIn(
        email: 'runner@example.com',
        password: 'run4medals',
      );

      expect(session.user.email, 'runner@example.com');
    });

    test('a successful sign in clears the failure count', () async {
      await failSignIns(FakeAuthRemoteDataSource.maxFailedSignIns - 1);
      await repository.signIn(
        email: 'runner@example.com',
        password: 'run4medals',
      );
      await failSignIns(FakeAuthRemoteDataSource.maxFailedSignIns - 1);

      final session = await repository.signIn(
        email: 'runner@example.com',
        password: 'run4medals',
      );

      expect(session.user.email, 'runner@example.com');
    });
  });

  group('changeEmail', () {
    Future<void> signUp() => repository.signUp(
      email: 'runner@example.com',
      password: 'run4medals',
      displayName: 'Lan',
    );

    Future<AuthFailure> failureOf(String email, String password) async {
      try {
        await repository.changeEmail(
          newEmail: email,
          currentPassword: password,
        );
      } on AuthFailure catch (failure) {
        return failure;
      }
      fail('Expected an AuthFailure');
    }

    test('changes the email, lowercase, and signs in with it', () async {
      await signUp();

      final user = await repository.changeEmail(
        newEmail: ' New.Runner@Example.com ',
        currentPassword: 'run4medals',
      );
      final session = await repository.signIn(
        email: 'new.runner@example.com',
        password: 'run4medals',
      );

      expect(user.email, 'new.runner@example.com');
      expect(session.user, user);
      await expectLater(
        repository.signIn(email: 'runner@example.com', password: 'run4medals'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('a refresh token issued before still works', () async {
      final first = await repository.signUp(
        email: 'runner@example.com',
        password: 'run4medals',
        displayName: 'Lan',
      );
      await repository.changeEmail(
        newEmail: 'new.runner@example.com',
        currentPassword: 'run4medals',
      );

      await repository.refresh(first.tokens.refreshToken);
    });

    test('a wrong password is incorrect_password', () async {
      await signUp();

      final failure = await failureOf('new.runner@example.com', 'wrong123');

      expect(failure.code, AuthFailureCode.incorrectPassword);
    });

    test(
      'the password is checked before the email is revealed as taken',
      () async {
        await signUp();

        final failure = await failureOf(
          FakeAuthRemoteDataSource.takenEmail,
          'bad',
        );

        expect(failure.code, AuthFailureCode.incorrectPassword);
      },
    );

    test('a known or registered email is email_taken', () async {
      await signUp();
      await repository.signUp(
        email: 'other@example.com',
        password: 'run4medals',
        displayName: 'Other',
      );
      // `other` signed up last, so it is the current user: it takes `runner`.
      final registered = await failureOf('runner@example.com', 'run4medals');
      final known = await failureOf(
        FakeAuthRemoteDataSource.takenEmail,
        'run4medals',
      );

      expect(registered.code, AuthFailureCode.emailTaken);
      expect(known.code, AuthFailureCode.emailTaken);
    });

    test('the same email in any case is a 422 naming new_email', () async {
      await signUp();

      final failure = await failureOf('Runner@Example.com', 'run4medals');

      expect(failure.code, AuthFailureCode.validation);
      expect(failure.fieldErrors.keys, ['new_email']);
    });

    test('a malformed email is a 422 naming new_email', () async {
      await signUp();

      final failure = await failureOf('nope', 'run4medals');

      expect(failure.code, AuthFailureCode.validation);
      expect(failure.fieldErrors.keys, ['new_email']);
    });

    test('wrong passwords are rate limited, with the wait', () async {
      await signUp();
      for (var i = 0; i < FakeAuthRemoteDataSource.maxFailedSignIns; i++) {
        await failureOf('new.runner@example.com', 'wrong123');
      }

      final failure = await failureOf('new.runner@example.com', 'run4medals');

      expect(failure.code, AuthFailureCode.rateLimited);
      expect(failure.retryAfter, isNotNull);
    });

    test('after sign out it is not_authenticated', () async {
      await signUp();
      final session = await repository.signIn(
        email: 'runner@example.com',
        password: 'run4medals',
      );
      await repository.signOut(session.tokens.refreshToken);

      final failure = await failureOf('new.runner@example.com', 'run4medals');

      expect(failure.code, AuthFailureCode.notAuthenticated);
    });

    test('without a session it is not_authenticated', () async {
      final failure = await failureOf('new.runner@example.com', 'run4medals');

      expect(failure.code, AuthFailureCode.notAuthenticated);
    });
  });

  group('changePassword', () {
    Future<AuthFailure> failureOf(String current, String next) async {
      try {
        await repository.changePassword(
          currentPassword: current,
          newPassword: next,
        );
      } on AuthFailure catch (failure) {
        return failure;
      }
      fail('Expected an AuthFailure');
    }

    Future<AuthSessionModel> signUp() => repository.signUp(
      email: 'runner@example.com',
      password: 'run4medals',
      displayName: 'Lan',
    );

    test('signs in with the new password only, with a new pair', () async {
      final first = await signUp();

      final tokens = await repository.changePassword(
        currentPassword: 'run4medals',
        newPassword: 'newrun5medals',
      );
      final session = await repository.signIn(
        email: 'runner@example.com',
        password: 'newrun5medals',
      );

      expect(tokens.refreshToken, isNot(first.tokens.refreshToken));
      expect(session.user, first.user);
      await expectLater(
        repository.signIn(email: 'runner@example.com', password: 'run4medals'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test(
      'the refresh token held before is revoked, the new one works',
      () async {
        final first = await signUp();
        final tokens = await repository.changePassword(
          currentPassword: 'run4medals',
          newPassword: 'newrun5medals',
        );

        await expectLater(
          repository.refresh(first.tokens.refreshToken),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.code,
              'code',
              AuthFailureCode.invalidRefreshToken,
            ),
          ),
        );
        await repository.refresh(tokens.refreshToken);
      },
    );

    test('a rule-breaking new password is a 422 naming new_password', () async {
      await signUp();

      for (final bad in ['short1', 'allletters', '123456789', 'a1' * 65]) {
        final failure = await failureOf('run4medals', bad);
        expect(failure.code, AuthFailureCode.validation, reason: bad);
        expect(failure.fieldErrors.keys, ['new_password'], reason: bad);
      }
    });

    test('field rules come before the password check', () async {
      await signUp();

      final failure = await failureOf('wrong123', 'short');

      expect(failure.code, AuthFailureCode.validation);
    });

    test('a wrong password is incorrect_password', () async {
      await signUp();

      final failure = await failureOf('wrong123', 'newrun5medals');

      expect(failure.code, AuthFailureCode.incorrectPassword);
    });

    test('the same password with a wrong current one is incorrect_password '
        'and counts as a failure', () async {
      await signUp();
      final first = await failureOf('wrong123', 'wrong123');
      expect(first.code, AuthFailureCode.incorrectPassword);
      for (var i = 1; i < FakeAuthRemoteDataSource.maxFailedSignIns; i++) {
        await failureOf('wrong123', 'wrong123');
      }

      final limited = await failureOf('wrong123', 'wrong123');

      expect(limited.code, AuthFailureCode.rateLimited);
    });

    test(
      'a rate limited user sending the same password is rate_limited',
      () async {
        await signUp();
        for (var i = 0; i < FakeAuthRemoteDataSource.maxFailedSignIns; i++) {
          await failureOf('wrong123', 'newrun5medals');
        }

        final failure = await failureOf('run4medals', 'run4medals');

        expect(failure.code, AuthFailureCode.rateLimited);
      },
    );

    test('the same password is a 422 naming new_password', () async {
      await signUp();

      final failure = await failureOf('run4medals', 'run4medals');

      expect(failure.code, AuthFailureCode.validation);
      expect(failure.fieldErrors.keys, ['new_password']);
    });

    test('wrong passwords are rate limited, even with the right one', () async {
      await signUp();
      for (var i = 0; i < FakeAuthRemoteDataSource.maxFailedSignIns; i++) {
        await failureOf('wrong123', 'newrun5medals');
      }

      final failure = await failureOf('run4medals', 'newrun5medals');

      expect(failure.code, AuthFailureCode.rateLimited);
      expect(failure.retryAfter, isNotNull);
    });

    test('without a session it is not_authenticated', () async {
      final failure = await failureOf('run4medals', 'newrun5medals');

      expect(failure.code, AuthFailureCode.notAuthenticated);
    });
  });
}

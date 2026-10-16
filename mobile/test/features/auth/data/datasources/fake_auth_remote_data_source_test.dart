import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/auth/data/datasources/fake_auth_remote_data_source.dart';
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
}

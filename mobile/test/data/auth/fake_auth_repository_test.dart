import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/data/auth/auth_failure.dart';
import 'package:stridequest/data/auth/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

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
}

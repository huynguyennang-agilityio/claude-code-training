import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/in_memory_auth_local_data_source.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late InMemoryAuthLocalDataSource local;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = _MockRemote();
    local = InMemoryAuthLocalDataSource();
    repository = AuthRepositoryImpl(remote, local);
  });

  tearDown(() => repository.dispose());

  test('signIn stores the session and returns the user', () async {
    when(
      () => remote.signIn(email: 'a@b.co', password: 'abc12345'),
    ).thenAnswer((_) async => testSession());

    final user = await repository.signIn(email: 'a@b.co', password: 'abc12345');

    expect(user, testUser.toEntity());
    expect(local.session, testSession());
    expect(await repository.accessToken(), 'access-1');
  });

  test('signIn failure stores nothing and rethrows', () async {
    when(
      () => remote.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(AuthFailure(AuthFailureCode.invalidCredentials));

    await expectLater(
      repository.signIn(email: 'a@b.co', password: 'wrong123'),
      throwsA(isA<AuthFailure>()),
    );
    expect(local.session, isNull);
  });

  test('signUp stores the session and returns the user', () async {
    when(
      () => remote.signUp(
        email: 'a@b.co',
        password: 'abc12345',
        displayName: 'A',
      ),
    ).thenAnswer((_) async => testSession());

    final user = await repository.signUp(
      email: 'a@b.co',
      password: 'abc12345',
      displayName: 'A',
    );

    expect(user.email, testUser.email);
    expect(local.session, testSession());
  });

  test('restoreSession returns the stored user, or null', () async {
    expect(await repository.restoreSession(), isNull);

    local.session = testSession();

    expect(await repository.restoreSession(), testUser.toEntity());
  });

  test('signOut clears locally even when the backend fails', () async {
    local.session = testSession();
    when(
      () => remote.signOut('refresh-1'),
    ).thenThrow(AuthFailure(AuthFailureCode.network));

    await repository.signOut();

    expect(local.session, isNull);
    verify(() => remote.signOut('refresh-1')).called(1);
  });

  test('refreshTokens swaps the stored tokens', () async {
    local.session = testSession();
    when(
      () => remote.refresh('refresh-1'),
    ).thenAnswer((_) async => testTokens(2));

    expect(await repository.refreshTokens(), isTrue);
    expect(local.session, testSession(2));
  });

  test('refreshTokens returns false when the backend rejects it', () async {
    local.session = testSession();
    when(
      () => remote.refresh(any()),
    ).thenThrow(AuthFailure(AuthFailureCode.invalidRefreshToken));

    expect(await repository.refreshTokens(), isFalse);
    expect(local.session, testSession());
  });

  test('refreshTokens returns false without a session', () async {
    expect(await repository.refreshTokens(), isFalse);
    verifyNever(() => remote.refresh(any()));
  });

  test('expireSession clears the session and notifies listeners', () async {
    local.session = testSession();
    final expired = expectLater(repository.sessionExpired, emits(null));

    await repository.expireSession();

    await expired;
    expect(local.session, isNull);
  });
}

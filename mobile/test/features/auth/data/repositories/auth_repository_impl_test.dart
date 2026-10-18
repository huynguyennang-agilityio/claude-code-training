import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/network/auth_token_handler.dart';
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/models/token_pair_model.dart';
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

  test('signIn and signUp announce the new session', () async {
    final started = <Object>[];
    final subscription = repository.sessionStarted.listen(started.add);
    addTearDown(subscription.cancel);
    when(
      () => remote.signIn(email: 'a@b.co', password: 'abc12345'),
    ).thenAnswer((_) async => testSession());
    when(
      () => remote.signUp(
        email: 'a@b.co',
        password: 'abc12345',
        displayName: 'A',
      ),
    ).thenAnswer((_) async => testSession());

    final user = await repository.signIn(email: 'a@b.co', password: 'abc12345');
    await repository.signUp(
      email: 'a@b.co',
      password: 'abc12345',
      displayName: 'A',
    );
    await Future<void>.delayed(Duration.zero);

    expect(started, hasLength(2));
    expect(started.first, user);
  });

  test('a failed signIn announces nothing', () async {
    final started = <Object>[];
    final subscription = repository.sessionStarted.listen(started.add);
    addTearDown(subscription.cancel);
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
    await Future<void>.delayed(Duration.zero);

    expect(started, isEmpty);
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

    expect(await repository.refreshTokens(), TokenRefreshResult.refreshed);
    expect(local.session, testSession(2));
  });

  for (final code in [
    AuthFailureCode.invalidRefreshToken,
    AuthFailureCode.validation,
  ]) {
    test('refreshTokens reports ${code.wireCode} as rejected', () async {
      local.session = testSession();
      when(() => remote.refresh(any())).thenThrow(AuthFailure(code));

      expect(await repository.refreshTokens(), TokenRefreshResult.rejected);
      expect(local.session, testSession());
    });
  }

  for (final code in [
    AuthFailureCode.network,
    AuthFailureCode.rateLimited,
    AuthFailureCode.unknown,
  ]) {
    test('refreshTokens keeps the session after ${code.wireCode}', () async {
      local.session = testSession();
      when(() => remote.refresh(any())).thenThrow(AuthFailure(code));

      expect(await repository.refreshTokens(), TokenRefreshResult.notRefreshed);
      expect(local.session, testSession());
    });
  }

  test('refreshTokens does nothing without a session', () async {
    expect(await repository.refreshTokens(), TokenRefreshResult.notRefreshed);
    verifyNever(() => remote.refresh(any()));
  });

  test('a sign-out during a refresh revokes the new token and keeps '
      'nothing', () async {
    local.session = testSession();
    final refresh = Completer<TokenPairModel>();
    when(() => remote.refresh('refresh-1')).thenAnswer((_) => refresh.future);
    when(() => remote.signOut(any())).thenAnswer((_) async {});

    final refreshing = repository.refreshTokens();
    final signingOut = repository.signOut();
    refresh.complete(testTokens(2));
    await Future.wait([refreshing, signingOut]);

    expect(local.session, isNull);
    verify(() => remote.signOut('refresh-2')).called(1);
    verifyNever(() => remote.signOut('refresh-1'));
  });

  test('a refresh queued after a sign-out stores nothing', () async {
    local.session = testSession();
    when(() => remote.signOut(any())).thenAnswer((_) async {});

    final signingOut = repository.signOut();
    final refreshing = repository.refreshTokens();
    await signingOut;

    expect(await refreshing, TokenRefreshResult.notRefreshed);
    expect(local.session, isNull);
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

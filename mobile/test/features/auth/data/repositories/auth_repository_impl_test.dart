import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/network/auth_token_handler.dart';
import 'package:stridequest/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stridequest/features/auth/data/models/auth_session_model.dart';
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

  group('changeEmail', () {
    final updated = testUser.copyWith(email: 'new.runner@example.com');

    setUp(() {
      when(
        () => remote.changeEmail(
          newEmail: 'new.runner@example.com',
          currentPassword: 'run4medals',
        ),
      ).thenAnswer((_) async => updated);
    });

    test('stores the new user, keeps the tokens and announces it', () async {
      local.session = testSession();
      final announced = <Object>[];
      final subscription = repository.userUpdated.listen(announced.add);
      addTearDown(subscription.cancel);

      final user = await repository.changeEmail(
        newEmail: 'new.runner@example.com',
        currentPassword: 'run4medals',
      );
      await Future<void>.delayed(Duration.zero);

      expect(user, updated.toEntity());
      expect(local.session, testSession().copyWith(user: updated));
      expect(announced, [user]);
    });

    test('a failure changes and announces nothing', () async {
      local.session = testSession();
      final announced = <Object>[];
      final subscription = repository.userUpdated.listen(announced.add);
      addTearDown(subscription.cancel);
      when(
        () => remote.changeEmail(
          newEmail: any(named: 'newEmail'),
          currentPassword: any(named: 'currentPassword'),
        ),
      ).thenThrow(AuthFailure(AuthFailureCode.incorrectPassword));

      await expectLater(
        repository.changeEmail(newEmail: 'x@y.co', currentPassword: 'bad'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.incorrectPassword,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(local.session, testSession());
      expect(announced, isEmpty);
    });

    test(
      'a sign-out during the request stores and announces nothing',
      () async {
        local.session = testSession();
        final announced = <Object>[];
        final subscription = repository.userUpdated.listen(announced.add);
        addTearDown(subscription.cancel);
        when(
          () => remote.changeEmail(
            newEmail: any(named: 'newEmail'),
            currentPassword: any(named: 'currentPassword'),
          ),
        ).thenAnswer((_) async {
          local.session = null;
          return updated;
        });

        await repository.changeEmail(
          newEmail: 'new.runner@example.com',
          currentPassword: 'run4medals',
        );
        await Future<void>.delayed(Duration.zero);

        expect(local.session, isNull);
        expect(announced, isEmpty);
      },
    );

    test('a response for another user stores and announces nothing', () async {
      final other = testSession().copyWith(
        user: testUser.copyWith(id: 'user-2'),
      );
      local.session = testSession();
      final announced = <Object>[];
      final subscription = repository.userUpdated.listen(announced.add);
      addTearDown(subscription.cancel);
      when(
        () => remote.changeEmail(
          newEmail: any(named: 'newEmail'),
          currentPassword: any(named: 'currentPassword'),
        ),
      ).thenAnswer((_) async {
        // User B signs in while user A's request is in flight.
        local.session = other;
        return updated;
      });

      await repository.changeEmail(
        newEmail: 'new.runner@example.com',
        currentPassword: 'run4medals',
      );
      await Future<void>.delayed(Duration.zero);

      expect(local.session, other);
      expect(announced, isEmpty);
    });

    test('a refresh during the request does not deadlock', () async {
      local.session = testSession();
      when(
        () => remote.changeEmail(
          newEmail: any(named: 'newEmail'),
          currentPassword: any(named: 'currentPassword'),
        ),
      ).thenAnswer((_) async {
        // What the auth interceptor does on a 401.
        await repository.refreshTokens();
        return updated;
      });
      when(() => remote.refresh(any())).thenAnswer((_) async => testTokens(2));

      await repository
          .changeEmail(newEmail: 'x@y.co', currentPassword: 'p')
          .timeout(const Duration(seconds: 2));

      expect(local.session?.tokens, testTokens(2));
      expect(local.session?.user, updated);
    });
  });

  group('deleteAccount', () {
    Future<void> delete() =>
        repository.deleteAccount(currentPassword: 'run4medals');

    test('clears the session after success, then announces it', () async {
      local.session = testSession();
      when(
        () => remote.deleteAccount(currentPassword: 'run4medals'),
      ).thenAnswer((_) async {});
      var clearedWhenAnnounced = false;
      final deleted = <Object?>[];
      final subscription = repository.accountDeleted.listen((_) {
        clearedWhenAnnounced = local.session == null;
        deleted.add(null);
      });
      addTearDown(subscription.cancel);

      await delete();
      await Future<void>.delayed(Duration.zero);

      expect(local.session, isNull);
      expect(deleted, hasLength(1));
      expect(clearedWhenAnnounced, isTrue);
      expect(await repository.accessToken(), isNull);
    });

    test('still announces it when clearing the session fails', () async {
      final failing = _ClearThrowingLocal()..session = testSession();
      final repo = AuthRepositoryImpl(remote, failing);
      addTearDown(repo.dispose);
      when(
        () => remote.deleteAccount(currentPassword: 'run4medals'),
      ).thenAnswer((_) async {});
      var deleted = 0;
      final subscription = repo.accountDeleted.listen((_) => deleted++);
      addTearDown(subscription.cancel);

      await repo.deleteAccount(currentPassword: 'run4medals');
      await Future<void>.delayed(Duration.zero);

      expect(deleted, 1);
    });

    test('a sign-out during the request leaves the session and announces '
        'nothing', () async {
      local.session = testSession();
      when(
        () => remote.deleteAccount(currentPassword: 'run4medals'),
      ).thenAnswer((_) async => local.session = null);
      final deleted = <Object?>[];
      final subscription = repository.accountDeleted.listen(deleted.add);
      addTearDown(subscription.cancel);

      await delete();
      await Future<void>.delayed(Duration.zero);

      expect(local.session, isNull);
      expect(deleted, isEmpty);
    });

    test("another user's sign-in during the request is kept and announces "
        'nothing', () async {
      local.session = testSession();
      final other = AuthSessionModel(
        user: testUser.copyWith(id: 'user-2', email: 'other@example.com'),
        tokens: testTokens(2),
      );
      when(
        () => remote.deleteAccount(currentPassword: 'run4medals'),
      ).thenAnswer((_) async => local.session = other);
      final deleted = <Object?>[];
      final subscription = repository.accountDeleted.listen(deleted.add);
      addTearDown(subscription.cancel);

      await delete();
      await Future<void>.delayed(Duration.zero);

      expect(local.session, other);
      expect(deleted, isEmpty);
    });

    for (final code in [
      AuthFailureCode.incorrectPassword,
      AuthFailureCode.lastAdmin,
      AuthFailureCode.rateLimited,
      AuthFailureCode.network,
    ]) {
      test('${code.wireCode} clears nothing and announces nothing', () async {
        local.session = testSession();
        when(
          () => remote.deleteAccount(currentPassword: 'run4medals'),
        ).thenThrow(AuthFailure(code));
        final deleted = <Object?>[];
        final subscription = repository.accountDeleted.listen(deleted.add);
        addTearDown(subscription.cancel);

        await expectLater(
          delete(),
          throwsA(isA<AuthFailure>().having((f) => f.code, 'code', code)),
        );
        await Future<void>.delayed(Duration.zero);

        expect(local.session, testSession());
        expect(deleted, isEmpty);
      });
    }
  });

  group('changePassword', () {
    setUp(() {
      when(
        () => remote.changePassword(
          currentPassword: 'run4medals',
          newPassword: 'newrun5medals',
        ),
      ).thenAnswer((_) async => testTokens(2));
    });

    Future<void> change() => repository.changePassword(
      currentPassword: 'run4medals',
      newPassword: 'newrun5medals',
    );

    test('stores the new pair for the same user before it returns', () async {
      local.session = testSession();

      await change();

      expect(local.session, testSession(2));
      expect(await repository.accessToken(), 'access-2');
    });

    test('a failure stores nothing', () async {
      local.session = testSession();
      when(
        () => remote.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenThrow(AuthFailure(AuthFailureCode.incorrectPassword));

      await expectLater(
        change(),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.incorrectPassword,
          ),
        ),
      );

      expect(local.session, testSession());
    });

    test('a failure to store the pair ends the session and says so', () async {
      final failing = _ThrowingLocal()..session = testSession();
      final repo = AuthRepositoryImpl(remote, failing);
      addTearDown(repo.dispose);
      var expired = 0;
      final subscription = repo.sessionExpired.listen((_) => expired++);
      addTearDown(subscription.cancel);

      await expectLater(
        repo.changePassword(
          currentPassword: 'run4medals',
          newPassword: 'newrun5medals',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.passwordChangedSignInAgain,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(failing.session, isNull);
      expect(expired, 1);
    });

    test('a sign-out during the request stores nothing', () async {
      local.session = testSession();
      when(
        () => remote.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {
        local.session = null;
        return testTokens(2);
      });

      await change();

      expect(local.session, isNull);
    });

    test('another user signing in during the request is left alone', () async {
      final other = testSession().copyWith(
        user: testUser.copyWith(id: 'user-2'),
      );
      local.session = testSession();
      when(
        () => remote.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {
        local.session = other;
        return testTokens(2);
      });

      await change();

      expect(local.session, other);
    });

    test('without a stored session it stores nothing', () async {
      await change();

      expect(local.session, isNull);
    });

    test('a refresh during the request does not deadlock', () async {
      local.session = testSession();
      when(
        () => remote.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {
        // What the auth interceptor does on a 401.
        await repository.refreshTokens();
        return testTokens(3);
      });
      when(() => remote.refresh(any())).thenAnswer((_) async => testTokens(2));

      await change().timeout(const Duration(seconds: 2));

      expect(local.session?.tokens, testTokens(3));
    });
  });
}

class _ThrowingLocal extends InMemoryAuthLocalDataSource {
  @override
  Future<void> saveSession(AuthSessionModel session) async =>
      throw StateError('storage failed');
}

class _ClearThrowingLocal extends InMemoryAuthLocalDataSource {
  @override
  Future<void> clear() async => throw StateError('storage failed');
}

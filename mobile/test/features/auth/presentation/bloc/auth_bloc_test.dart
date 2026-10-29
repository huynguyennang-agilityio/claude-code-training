import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/entities/auth_user.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';

import '../../../../helpers/auth_fixtures.dart';

class _MockRepository extends Mock implements AuthRepository {}

void main() {
  final user = testUser.toEntity();
  late _MockRepository repository;
  late StreamController<void> sessionExpired;
  late StreamController<AuthUser> sessionStarted;
  late StreamController<AuthUser> userUpdated;
  late StreamController<void> accountDeleted;

  setUp(() {
    repository = _MockRepository();
    sessionExpired = StreamController<void>.broadcast();
    sessionStarted = StreamController<AuthUser>.broadcast();
    userUpdated = StreamController<AuthUser>.broadcast();
    accountDeleted = StreamController<void>.broadcast();
    when(
      () => repository.accountDeleted,
    ).thenAnswer((_) => accountDeleted.stream);
    when(() => repository.userUpdated).thenAnswer((_) => userUpdated.stream);
    when(
      () => repository.sessionStarted,
    ).thenAnswer((_) => sessionStarted.stream);
    when(
      () => repository.sessionExpired,
    ).thenAnswer((_) => sessionExpired.stream);
  });

  tearDown(() async {
    await sessionExpired.close();
    await sessionStarted.close();
    await userUpdated.close();
    await accountDeleted.close();
  });

  test('starts unknown', () async {
    final bloc = AuthBloc(repository);
    addTearDown(bloc.close);

    expect(bloc.state, const AuthUnknown());
  });

  blocTest<AuthBloc, AuthState>(
    'restores a stored session',
    setUp: () =>
        when(() => repository.restoreSession()).thenAnswer((_) async => user),
    build: () => AuthBloc(repository),
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [AuthAuthenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'is unauthenticated without a stored session',
    setUp: () =>
        when(() => repository.restoreSession()).thenAnswer((_) async => null),
    build: () => AuthBloc(repository),
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const AuthUnauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'becomes authenticated when the repository starts a session',
    build: () => AuthBloc(repository),
    act: (_) => sessionStarted.add(user),
    expect: () => [AuthAuthenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'does not need the sign-in or sign-up form: a started session is enough',
    build: () => AuthBloc(repository),
    seed: () => const AuthUnauthenticated(sessionExpired: true),
    act: (_) => sessionStarted.add(user),
    expect: () => [AuthAuthenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'signs out',
    setUp: () => when(() => repository.signOut()).thenAnswer((_) async {}),
    build: () => AuthBloc(repository),
    seed: () => AuthAuthenticated(user),
    act: (bloc) => bloc.add(const AuthSignOutRequested()),
    expect: () => [const AuthUnauthenticated()],
    verify: (_) => verify(() => repository.signOut()).called(1),
  );

  blocTest<AuthBloc, AuthState>(
    'becomes unauthenticated when the repository expires the session',
    build: () => AuthBloc(repository),
    seed: () => AuthAuthenticated(user),
    act: (_) => sessionExpired.add(null),
    expect: () => [const AuthUnauthenticated(sessionExpired: true)],
  );

  blocTest<AuthBloc, AuthState>(
    'says the account was deleted when the repository announces it',
    build: () => AuthBloc(repository),
    seed: () => AuthAuthenticated(user),
    act: (_) => accountDeleted.add(null),
    expect: () => [const AuthUnauthenticated(accountDeleted: true)],
  );

  blocTest<AuthBloc, AuthState>(
    'a session expiry after a deleted account keeps the deleted notice',
    build: () => AuthBloc(repository),
    seed: () => AuthAuthenticated(user),
    act: (_) async {
      accountDeleted.add(null);
      await Future<void>.delayed(Duration.zero);
      sessionExpired.add(null);
    },
    expect: () => [const AuthUnauthenticated(accountDeleted: true)],
  );

  test('a deleted account is not a session expiry', () {
    expect(
      const AuthUnauthenticated(accountDeleted: true),
      isNot(const AuthUnauthenticated(sessionExpired: true)),
    );
    expect(
      const AuthUnauthenticated(accountDeleted: true).sessionExpired,
      false,
    );
  });

  final updated = AuthUser(
    id: user.id,
    email: 'new.runner@example.com',
    displayName: user.displayName,
    createdAt: user.createdAt,
  );

  blocTest<AuthBloc, AuthState>(
    'shows the new email when the repository updates the user',
    build: () => AuthBloc(repository),
    seed: () => AuthAuthenticated(user),
    act: (_) => userUpdated.add(updated),
    expect: () => [AuthAuthenticated(updated)],
  );

  blocTest<AuthBloc, AuthState>(
    'a late user update does not sign anyone back in',
    build: () => AuthBloc(repository),
    seed: () => const AuthUnauthenticated(),
    act: (_) => userUpdated.add(updated),
    expect: () => <AuthState>[],
  );
}

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';

import '../../../../helpers/auth_fixtures.dart';

class _MockRepository extends Mock implements AuthRepository {}

void main() {
  final user = testUser.toEntity();
  late _MockRepository repository;
  late StreamController<void> sessionExpired;

  setUp(() {
    repository = _MockRepository();
    sessionExpired = StreamController<void>.broadcast();
    when(
      () => repository.sessionExpired,
    ).thenAnswer((_) => sessionExpired.stream);
  });

  tearDown(() => sessionExpired.close());

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
    'signs in',
    setUp: () => when(
      () => repository.signIn(email: 'a@b.co', password: 'abc12345'),
    ).thenAnswer((_) async => user),
    build: () => AuthBloc(repository),
    act: (bloc) => bloc.add(
      const AuthSignInRequested(email: 'a@b.co', password: 'abc12345'),
    ),
    expect: () => [const AuthInProgress(), AuthAuthenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'reports a failed sign in',
    setUp: () => when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(AuthFailure(AuthFailureCode.invalidCredentials)),
    build: () => AuthBloc(repository),
    act: (bloc) => bloc.add(
      const AuthSignInRequested(email: 'a@b.co', password: 'wrong123'),
    ),
    expect: () => [
      const AuthInProgress(),
      AuthUnauthenticated(
        failure: AuthFailure(AuthFailureCode.invalidCredentials),
      ),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'signs up',
    setUp: () => when(
      () => repository.signUp(
        email: 'a@b.co',
        password: 'abc12345',
        displayName: 'A',
      ),
    ).thenAnswer((_) async => user),
    build: () => AuthBloc(repository),
    act: (bloc) => bloc.add(
      const AuthSignUpRequested(
        email: 'a@b.co',
        password: 'abc12345',
        displayName: 'A',
      ),
    ),
    expect: () => [const AuthInProgress(), AuthAuthenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'reports a failed sign up with its field errors',
    setUp: () => when(
      () => repository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
      ),
    ).thenThrow(AuthFailure(AuthFailureCode.emailTaken)),
    build: () => AuthBloc(repository),
    act: (bloc) => bloc.add(
      const AuthSignUpRequested(
        email: 'a@b.co',
        password: 'abc12345',
        displayName: 'A',
      ),
    ),
    expect: () => [
      const AuthInProgress(),
      AuthUnauthenticated(failure: AuthFailure(AuthFailureCode.emailTaken)),
    ],
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
}

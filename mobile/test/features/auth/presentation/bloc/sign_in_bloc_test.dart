import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/sign_in_bloc.dart';

import '../../../../helpers/auth_fixtures.dart';

class _MockRepository extends Mock implements AuthRepository {}

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  test('starts initial', () async {
    final bloc = SignInBloc(repository);
    addTearDown(bloc.close);

    expect(bloc.state, const SignInInitial());
  });

  blocTest<SignInBloc, SignInState>(
    'signs in through the repository',
    setUp: () => when(
      () => repository.signIn(email: 'a@b.co', password: 'abc12345'),
    ).thenAnswer((_) async => testUser.toEntity()),
    build: () => SignInBloc(repository),
    act: (bloc) =>
        bloc.add(const SignInSubmitted(email: 'a@b.co', password: 'abc12345')),
    expect: () => [const SignInInProgress(), const SignInSucceeded()],
    verify: (_) => verify(
      () => repository.signIn(email: 'a@b.co', password: 'abc12345'),
    ).called(1),
  );

  blocTest<SignInBloc, SignInState>(
    'reports a failed sign in with its failure',
    setUp: () => when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(AuthFailure(AuthFailureCode.invalidCredentials)),
    build: () => SignInBloc(repository),
    act: (bloc) =>
        bloc.add(const SignInSubmitted(email: 'a@b.co', password: 'wrong123')),
    expect: () => [
      const SignInInProgress(),
      isA<SignInFailed>().having(
        (state) => state.failure.code,
        'code',
        AuthFailureCode.invalidCredentials,
      ),
    ],
  );

  blocTest<SignInBloc, SignInState>(
    'can try again after a failure',
    setUp: () {
      var calls = 0;
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw AuthFailure(AuthFailureCode.network);
        return testUser.toEntity();
      });
    },
    build: () => SignInBloc(repository),
    act: (bloc) async {
      const event = SignInSubmitted(email: 'a@b.co', password: 'abc12345');
      bloc.add(event);
      await Future<void>.delayed(Duration.zero);
      bloc.add(event);
    },
    expect: () => [
      const SignInInProgress(),
      isA<SignInFailed>(),
      const SignInInProgress(),
      const SignInSucceeded(),
    ],
  );
}

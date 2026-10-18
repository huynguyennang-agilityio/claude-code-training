import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/sign_up_bloc.dart';

import '../../../../helpers/auth_fixtures.dart';

class _MockRepository extends Mock implements AuthRepository {}

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  test('starts initial', () async {
    final bloc = SignUpBloc(repository);
    addTearDown(bloc.close);

    expect(bloc.state, const SignUpInitial());
  });

  blocTest<SignUpBloc, SignUpState>(
    'signs up through the repository',
    setUp: () => when(
      () => repository.signUp(
        email: 'a@b.co',
        password: 'abc12345',
        displayName: 'A',
      ),
    ).thenAnswer((_) async => testUser.toEntity()),
    build: () => SignUpBloc(repository),
    act: (bloc) => bloc.add(
      const SignUpSubmitted(
        email: 'a@b.co',
        password: 'abc12345',
        displayName: 'A',
      ),
    ),
    expect: () => [const SignUpInProgress(), const SignUpSucceeded()],
  );

  blocTest<SignUpBloc, SignUpState>(
    'reports a taken email',
    setUp: () => when(
      () => repository.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
      ),
    ).thenThrow(AuthFailure(AuthFailureCode.emailTaken)),
    build: () => SignUpBloc(repository),
    act: (bloc) => bloc.add(
      const SignUpSubmitted(
        email: 'a@b.co',
        password: 'abc12345',
        displayName: 'A',
      ),
    ),
    expect: () => [
      const SignUpInProgress(),
      isA<SignUpFailed>().having(
        (state) => state.failure.code,
        'code',
        AuthFailureCode.emailTaken,
      ),
    ],
  );

  blocTest<SignUpBloc, SignUpState>(
    'reports field errors from a validation failure',
    setUp: () =>
        when(
          () => repository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          ),
        ).thenThrow(
          AuthFailure(
            AuthFailureCode.validation,
            fieldErrors: const {'password': 'Too weak.'},
          ),
        ),
    build: () => SignUpBloc(repository),
    act: (bloc) => bloc.add(
      const SignUpSubmitted(
        email: 'a@b.co',
        password: 'abc12345',
        displayName: 'A',
      ),
    ),
    expect: () => [
      const SignUpInProgress(),
      isA<SignUpFailed>().having(
        (state) => state.failure.fieldErrors,
        'fieldErrors',
        {'password': 'Too weak.'},
      ),
    ],
  );
}

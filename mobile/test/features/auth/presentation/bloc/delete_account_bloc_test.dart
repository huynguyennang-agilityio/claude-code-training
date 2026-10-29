import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/delete_account_bloc.dart';

import '../../../../helpers/auth_fixtures.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  void stubDelete() => when(
    () => repository.deleteAccount(currentPassword: 'run4medals'),
  ).thenAnswer((_) async {});

  void failWith(Object error) => when(
    () => repository.deleteAccount(
      currentPassword: any(named: 'currentPassword'),
    ),
  ).thenThrow(error);

  const typed = DeleteAccountState(password: 'run4medals');
  const submitting = DeleteAccountState(
    password: 'run4medals',
    status: DeleteAccountStatus.submitting,
  );

  test('starts idle with the button off', () {
    final bloc = DeleteAccountBloc(repository);
    addTearDown(bloc.close);

    expect(bloc.state, const DeleteAccountState());
    expect(bloc.state.canSubmit, isFalse);
    expect(typed.canSubmit, isTrue);
    expect(submitting.canSubmit, isFalse);
  });

  blocTest<DeleteAccountBloc, DeleteAccountState>(
    'typing turns the button on',
    build: () => DeleteAccountBloc(repository),
    act: (bloc) => bloc.add(const DeleteAccountPasswordChanged('run4medals')),
    expect: () => [typed],
  );

  blocTest<DeleteAccountBloc, DeleteAccountState>(
    'submitting without a password does nothing',
    build: () => DeleteAccountBloc(repository),
    act: (bloc) => bloc.add(const DeleteAccountSubmitted()),
    expect: () => <DeleteAccountState>[],
    verify: (_) => verifyNever(
      () => repository.deleteAccount(
        currentPassword: any(named: 'currentPassword'),
      ),
    ),
  );

  blocTest<DeleteAccountBloc, DeleteAccountState>(
    'a delete goes submitting then success, with the password as typed',
    setUp: stubDelete,
    build: () => DeleteAccountBloc(repository),
    seed: () => typed,
    act: (bloc) => bloc.add(const DeleteAccountSubmitted()),
    expect: () => [
      submitting,
      const DeleteAccountState(
        password: 'run4medals',
        status: DeleteAccountStatus.success,
      ),
    ],
    verify: (_) => verify(
      () => repository.deleteAccount(currentPassword: 'run4medals'),
    ).called(1),
  );

  blocTest<DeleteAccountBloc, DeleteAccountState>(
    'a second submit while one runs is ignored',
    setUp: () {
      final completer = Completer<void>();
      when(
        () => repository.deleteAccount(currentPassword: 'run4medals'),
      ).thenAnswer((_) => completer.future);
    },
    build: () => DeleteAccountBloc(repository),
    seed: () => typed,
    act: (bloc) => bloc
      ..add(const DeleteAccountSubmitted())
      ..add(const DeleteAccountSubmitted())
      ..add(const DeleteAccountPasswordChanged('other')),
    expect: () => [submitting],
    verify: (_) => verify(
      () => repository.deleteAccount(currentPassword: 'run4medals'),
    ).called(1),
  );

  for (final code in [
    AuthFailureCode.incorrectPassword,
    AuthFailureCode.rateLimited,
    AuthFailureCode.lastAdmin,
    AuthFailureCode.network,
  ]) {
    blocTest<DeleteAccountBloc, DeleteAccountState>(
      '${code.wireCode} ends in failure and keeps the password',
      setUp: () => failWith(AuthFailure(code)),
      build: () => DeleteAccountBloc(repository),
      seed: () => typed,
      act: (bloc) => bloc.add(const DeleteAccountSubmitted()),
      expect: () => [
        submitting,
        isA<DeleteAccountState>()
            .having((s) => s.status, 'status', DeleteAccountStatus.failure)
            .having((s) => s.password, 'password', 'run4medals')
            .having((s) => s.failure?.code, 'code', code)
            .having((s) => s.canSubmit, 'canSubmit', isTrue)
            .having((s) => s.banner, 'banner', code.defaultMessage),
      ],
    );
  }

  blocTest<DeleteAccountBloc, DeleteAccountState>(
    'rate_limited says how long to wait',
    setUp: () => failWith(
      AuthFailure(
        AuthFailureCode.rateLimited,
        retryAfter: const Duration(seconds: 90),
      ),
    ),
    build: () => DeleteAccountBloc(repository),
    seed: () => typed,
    act: (bloc) => bloc.add(const DeleteAccountSubmitted()),
    expect: () => [
      submitting,
      isA<DeleteAccountState>().having(
        (s) => s.banner,
        'banner',
        contains('Try again in 2 minutes.'),
      ),
    ],
  );

  blocTest<DeleteAccountBloc, DeleteAccountState>(
    'an unexpected error ends in failure instead of staying submitting',
    setUp: () => failWith(StateError('boom')),
    build: () => DeleteAccountBloc(repository),
    seed: () => typed,
    act: (bloc) => bloc.add(const DeleteAccountSubmitted()),
    expect: () => [
      submitting,
      isA<DeleteAccountState>().having(
        (s) => s.failure?.code,
        'code',
        AuthFailureCode.unknown,
      ),
    ],
  );

  blocTest<DeleteAccountBloc, DeleteAccountState>(
    'typing after a failure clears the error, and a retry can succeed',
    setUp: () {
      failWith(AuthFailure(AuthFailureCode.incorrectPassword));
    },
    build: () => DeleteAccountBloc(repository),
    seed: () => typed,
    act: (bloc) async {
      bloc.add(const DeleteAccountSubmitted());
      await Future<void>.delayed(Duration.zero);
      stubDelete();
      bloc
        ..add(const DeleteAccountPasswordChanged('run4medals'))
        ..add(const DeleteAccountSubmitted());
    },
    expect: () => [
      submitting,
      isA<DeleteAccountState>().having(
        (s) => s.status,
        'status',
        DeleteAccountStatus.failure,
      ),
      typed,
      submitting,
      isA<DeleteAccountState>().having(
        (s) => s.status,
        'status',
        DeleteAccountStatus.success,
      ),
    ],
  );

  group('password length', () {
    const message = 'Passwords are up to 128 characters.';
    final atLimit = DeleteAccountState(password: 'a' * 128);
    final overLimit = DeleteAccountState(password: 'a' * 129);

    test('128 characters can be submitted', () {
      expect(atLimit.canSubmit, isTrue);
      expect(atLimit.lengthError, isNull);
    });

    test('129 characters show an error and cannot be submitted', () {
      expect(overLimit.canSubmit, isFalse);
      expect(overLimit.lengthError, message);
    });

    blocTest<DeleteAccountBloc, DeleteAccountState>(
      'submitting 129 characters calls nothing',
      build: () => DeleteAccountBloc(repository),
      seed: () => overLimit,
      act: (bloc) => bloc.add(const DeleteAccountSubmitted()),
      expect: () => <DeleteAccountState>[],
      verify: (_) => verifyZeroInteractions(repository),
    );
  });
}

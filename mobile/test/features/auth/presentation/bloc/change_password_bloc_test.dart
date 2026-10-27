import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_password_bloc.dart';

import '../../../../helpers/auth_fixtures.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  ChangePasswordState form({
    String current = 'run4medals',
    String newPassword = 'newrun5medals',
    String? confirm,
    ChangePasswordStatus status = ChangePasswordStatus.editing,
    String? currentError,
    String? newError,
    String? banner,
  }) => ChangePasswordState(
    current: current,
    newPassword: newPassword,
    confirm: confirm ?? newPassword,
    status: status,
    currentError: currentError,
    newError: newError,
    banner: banner,
  );

  void failWith(Object error) => when(
    () => repository.changePassword(
      currentPassword: any(named: 'currentPassword'),
      newPassword: any(named: 'newPassword'),
    ),
  ).thenThrow(error);

  group('the form state', () {
    test('Save needs all three filled, a valid new password and a match', () {
      expect(form().canSave, isTrue);
      expect(form(current: '').canSave, isFalse);
      expect(form(newPassword: '', confirm: '').canSave, isFalse);
      expect(form(confirm: 'other5medals').canSave, isFalse);
      expect(form(confirm: '').canSave, isFalse);
      expect(form(status: ChangePasswordStatus.saving).canSave, isFalse);
    });

    test('the new password follows the contract rule', () {
      bool valid(String p) => form(newPassword: p, confirm: p).canSave;

      expect(valid('abcdefg1'), isTrue);
      expect(valid('abcdef1'), isFalse, reason: '7 characters');
      expect(valid('abcdefgh'), isFalse, reason: 'no digit');
      expect(valid('12345678'), isFalse, reason: 'no letter');
      expect(valid('${'a' * 127}1'), isTrue, reason: '128 characters');
      expect(valid('${'a' * 128}1'), isFalse, reason: '129 characters');
    });

    test('the rule error shows only for text that breaks the rule', () {
      expect(form(newPassword: '', confirm: '').ruleError, isNull);
      expect(form(newPassword: 'short1', confirm: '').ruleError, isNotNull);
      expect(form().ruleError, isNull);
    });

    test('the mismatch error shows once Confirm has text that differs', () {
      expect(form(confirm: '').mismatchError, isNull);
      expect(form(confirm: 'new').mismatchError, 'Passwords do not match.');
      expect(form().mismatchError, isNull);
    });
  });

  blocTest<ChangePasswordBloc, ChangePasswordState>(
    'typing updates the form',
    build: () => ChangePasswordBloc(repository),
    act: (bloc) => bloc
      ..add(const ChangePasswordCurrentChanged('run4medals'))
      ..add(const ChangePasswordNewChanged('newrun5medals'))
      ..add(const ChangePasswordConfirmChanged('newrun5medals')),
    expect: () => [
      form(newPassword: '', confirm: ''),
      form(confirm: ''),
      form(),
    ],
  );

  blocTest<ChangePasswordBloc, ChangePasswordState>(
    'editing a field clears its own server error and the banner only',
    build: () => ChangePasswordBloc(repository),
    seed: () => form(currentError: 'wrong', newError: 'rule', banner: 'b'),
    act: (bloc) => bloc.add(const ChangePasswordNewChanged('other5medals')),
    expect: () => [
      form(
        newPassword: 'other5medals',
        confirm: 'newrun5medals',
        currentError: 'wrong',
      ),
    ],
  );

  blocTest<ChangePasswordBloc, ChangePasswordState>(
    'saves both passwords, without AuthBloc',
    setUp: () => when(
      () => repository.changePassword(
        currentPassword: 'run4medals',
        newPassword: 'newrun5medals',
      ),
    ).thenAnswer((_) async {}),
    build: () => ChangePasswordBloc(repository),
    seed: form,
    act: (bloc) => bloc.add(const ChangePasswordSubmitted()),
    expect: () => [
      form(status: ChangePasswordStatus.saving),
      form(status: ChangePasswordStatus.saved),
    ],
  );

  blocTest<ChangePasswordBloc, ChangePasswordState>(
    'ignores Save while it cannot be saved',
    build: () => ChangePasswordBloc(repository),
    seed: () => form(confirm: 'nope'),
    act: (bloc) => bloc.add(const ChangePasswordSubmitted()),
    expect: () => <ChangePasswordState>[],
    verify: (_) => verifyNever(
      () => repository.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ),
  );

  group('failures', () {
    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'incorrect_password goes under Current Password',
      setUp: () => failWith(AuthFailure(AuthFailureCode.incorrectPassword)),
      build: () => ChangePasswordBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangePasswordSubmitted()),
      skip: 1,
      expect: () => [form(currentError: 'The current password is incorrect.')],
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'a new_password 422 goes under New Password',
      setUp: () => failWith(
        AuthFailure(
          AuthFailureCode.validation,
          fieldErrors: const {'new_password': 'Must differ.'},
        ),
      ),
      build: () => ChangePasswordBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangePasswordSubmitted()),
      skip: 1,
      expect: () => [form(newError: 'Must differ.')],
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'rate_limited is a banner with the wait',
      setUp: () => failWith(
        AuthFailure(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 3),
        ),
      ),
      build: () => ChangePasswordBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangePasswordSubmitted()),
      skip: 1,
      expect: () => [
        form(
          banner:
              'Too many attempts. Wait a few minutes and try again. '
              'Try again in 3 minutes.',
        ),
      ],
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'a field error for another field goes to the banner',
      setUp: () => failWith(
        AuthFailure(
          AuthFailureCode.validation,
          fieldErrors: const {'extra': 'Not allowed.'},
        ),
      ),
      build: () => ChangePasswordBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangePasswordSubmitted()),
      skip: 1,
      expect: () => [form(banner: 'Not allowed.')],
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'a network failure is a banner and keeps what was typed',
      setUp: () => failWith(AuthFailure(AuthFailureCode.network)),
      build: () => ChangePasswordBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangePasswordSubmitted()),
      skip: 1,
      expect: () => [
        form(banner: 'Cannot reach StrideQuest. Check your connection.'),
      ],
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'an error that is not an AuthFailure is a banner, not a stuck save',
      setUp: () => failWith(StateError('storage failed')),
      build: () => ChangePasswordBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangePasswordSubmitted()),
      skip: 1,
      expect: () => [form(banner: 'Something went wrong. Try again.')],
    );

    blocTest<ChangePasswordBloc, ChangePasswordState>(
      'a password changed but not stored tells the user to sign in again',
      setUp: () =>
          failWith(AuthFailure(AuthFailureCode.passwordChangedSignInAgain)),
      build: () => ChangePasswordBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangePasswordSubmitted()),
      skip: 1,
      expect: () => [
        form(
          banner:
              'Your password was changed, but this device could not keep the '
              'new session. Sign in again with your new password.',
        ),
      ],
    );
  });
}

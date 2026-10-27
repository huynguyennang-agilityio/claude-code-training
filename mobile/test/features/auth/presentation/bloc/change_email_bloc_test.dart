import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/auth/domain/failures/auth_failure.dart';
import 'package:stridequest/features/auth/presentation/bloc/change_email_bloc.dart';

import '../../../../helpers/auth_fixtures.dart';

void main() {
  final user = testUser.toEntity();
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(repository.restoreSession).thenAnswer((_) async => user);
  });

  ChangeEmailForm form({
    String newEmail = 'new.runner@example.com',
    String password = 'run4medals',
    ChangeEmailStatus status = ChangeEmailStatus.editing,
    String? emailError,
    String? passwordError,
    String? banner,
  }) => ChangeEmailForm(
    currentEmail: user.email,
    newEmail: newEmail,
    password: password,
    status: status,
    emailError: emailError,
    passwordError: passwordError,
    banner: banner,
  );

  void failWith(AuthFailure failure) => when(
    () => repository.changeEmail(
      newEmail: any(named: 'newEmail'),
      currentPassword: any(named: 'currentPassword'),
    ),
  ).thenThrow(failure);

  group('the form state', () {
    test('Save needs a changed, valid email and a password', () {
      expect(form().canSave, isTrue);
      expect(form(newEmail: user.email).canSave, isFalse);
      expect(form(newEmail: 'RUNNER@example.com ').canSave, isFalse);
      expect(form(newEmail: 'not-an-email').canSave, isFalse);
      expect(form(password: '').canSave, isFalse);
      expect(form(status: ChangeEmailStatus.saving).canSave, isFalse);
    });

    test('a format error shows only for text that is not an email', () {
      expect(form(newEmail: 'runner@').formatError, isNotNull);
      expect(form(newEmail: '').formatError, isNull);
      expect(form().formatError, isNull);
      expect(form(newEmail: '${'a' * 250}@b.co').formatError, isNotNull);
    });
  });

  blocTest<ChangeEmailBloc, ChangeEmailState>(
    'starts with the current email in the field',
    build: () => ChangeEmailBloc(repository),
    act: (bloc) => bloc.add(const ChangeEmailStarted()),
    expect: () => [
      const ChangeEmailLoading(),
      ChangeEmailForm(currentEmail: user.email, newEmail: user.email),
    ],
  );

  blocTest<ChangeEmailBloc, ChangeEmailState>(
    'fails to load without a stored session, and Try again reloads',
    setUp: () => when(repository.restoreSession).thenAnswer((_) async => null),
    build: () => ChangeEmailBloc(repository),
    act: (bloc) => bloc
      ..add(const ChangeEmailStarted())
      ..add(const ChangeEmailStarted()),
    expect: () => [
      const ChangeEmailLoading(),
      isA<ChangeEmailLoadFailed>().having(
        (state) => state.failure.code,
        'code',
        AuthFailureCode.notAuthenticated,
      ),
      const ChangeEmailLoading(),
      isA<ChangeEmailLoadFailed>(),
    ],
  );

  blocTest<ChangeEmailBloc, ChangeEmailState>(
    'typing updates the form',
    build: () => ChangeEmailBloc(repository),
    seed: () => form(newEmail: user.email, password: ''),
    act: (bloc) => bloc
      ..add(const ChangeEmailEmailChanged('new.runner@example.com'))
      ..add(const ChangeEmailPasswordChanged('run4medals')),
    expect: () => [form(password: ''), form()],
  );

  blocTest<ChangeEmailBloc, ChangeEmailState>(
    'editing a field clears its own server error and the banner only',
    build: () => ChangeEmailBloc(repository),
    seed: () => form(emailError: 'taken', passwordError: 'wrong', banner: 'b'),
    act: (bloc) => bloc.add(const ChangeEmailEmailChanged('other@example.com')),
    expect: () => [form(newEmail: 'other@example.com', passwordError: 'wrong')],
  );

  blocTest<ChangeEmailBloc, ChangeEmailState>(
    'saves the trimmed email and the password, without AuthBloc',
    setUp: () => when(
      () => repository.changeEmail(
        newEmail: 'new.runner@example.com',
        currentPassword: 'run4medals',
      ),
    ).thenAnswer((_) async => user),
    build: () => ChangeEmailBloc(repository),
    seed: () => form(newEmail: ' new.runner@example.com '),
    act: (bloc) => bloc.add(const ChangeEmailSubmitted()),
    expect: () => [
      form(
        newEmail: ' new.runner@example.com ',
        status: ChangeEmailStatus.saving,
      ),
      form(
        newEmail: ' new.runner@example.com ',
        status: ChangeEmailStatus.saved,
      ),
    ],
  );

  blocTest<ChangeEmailBloc, ChangeEmailState>(
    'ignores Save while it cannot be saved',
    build: () => ChangeEmailBloc(repository),
    seed: () => form(password: ''),
    act: (bloc) => bloc.add(const ChangeEmailSubmitted()),
    expect: () => <ChangeEmailState>[],
    verify: (_) => verifyNever(
      () => repository.changeEmail(
        newEmail: any(named: 'newEmail'),
        currentPassword: any(named: 'currentPassword'),
      ),
    ),
  );

  group('failures', () {
    blocTest<ChangeEmailBloc, ChangeEmailState>(
      'incorrect_password goes under Current Password',
      setUp: () => failWith(AuthFailure(AuthFailureCode.incorrectPassword)),
      build: () => ChangeEmailBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangeEmailSubmitted()),
      skip: 1,
      expect: () => [form(passwordError: 'The current password is incorrect.')],
    );

    blocTest<ChangeEmailBloc, ChangeEmailState>(
      'email_taken goes under the email',
      setUp: () => failWith(AuthFailure(AuthFailureCode.emailTaken)),
      build: () => ChangeEmailBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangeEmailSubmitted()),
      skip: 1,
      expect: () => [
        form(emailError: 'An account with this email already exists.'),
      ],
    );

    blocTest<ChangeEmailBloc, ChangeEmailState>(
      'a new_email 422 goes under the email',
      setUp: () => failWith(
        AuthFailure(
          AuthFailureCode.validation,
          fieldErrors: const {'new_email': 'Must differ.'},
        ),
      ),
      build: () => ChangeEmailBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangeEmailSubmitted()),
      skip: 1,
      expect: () => [form(emailError: 'Must differ.')],
    );

    blocTest<ChangeEmailBloc, ChangeEmailState>(
      'rate_limited is a banner with the wait',
      setUp: () => failWith(
        AuthFailure(
          AuthFailureCode.rateLimited,
          retryAfter: const Duration(minutes: 3),
        ),
      ),
      build: () => ChangeEmailBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangeEmailSubmitted()),
      skip: 1,
      expect: () => [
        form(
          banner:
              'Too many attempts. Wait a few minutes and try again. '
              'Try again in 3 minutes.',
        ),
      ],
    );

    blocTest<ChangeEmailBloc, ChangeEmailState>(
      'a field error for another field goes to the banner',
      setUp: () => failWith(
        AuthFailure(
          AuthFailureCode.validation,
          fieldErrors: const {'extra': 'Not allowed.'},
        ),
      ),
      build: () => ChangeEmailBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangeEmailSubmitted()),
      skip: 1,
      expect: () => [form(banner: 'Not allowed.')],
    );

    blocTest<ChangeEmailBloc, ChangeEmailState>(
      'a network failure is a banner and keeps what was typed',
      setUp: () => failWith(AuthFailure(AuthFailureCode.network)),
      build: () => ChangeEmailBloc(repository),
      seed: form,
      act: (bloc) => bloc.add(const ChangeEmailSubmitted()),
      skip: 1,
      expect: () => [
        form(banner: 'Cannot reach StrideQuest. Check your connection.'),
      ],
    );
  });
}

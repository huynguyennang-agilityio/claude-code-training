import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

part 'change_email_event.dart';
part 'change_email_state.dart';

/// The Email form. A factory bloc created in the route, so it closes with the
/// page.
///
/// It never touches `AuthBloc`: on success the repository announces the
/// updated user on `userUpdated` and `AuthBloc` picks it up.
@injectable
class ChangeEmailBloc extends Bloc<ChangeEmailEvent, ChangeEmailState> {
  ChangeEmailBloc(this._repository) : super(const ChangeEmailLoading()) {
    on<ChangeEmailStarted>(_onStarted);
    on<ChangeEmailEmailChanged>(_onEmailChanged);
    on<ChangeEmailPasswordChanged>(_onPasswordChanged);
    on<ChangeEmailSubmitted>(_onSubmitted);
  }

  final AuthRepository _repository;

  Future<void> _onStarted(
    ChangeEmailStarted event,
    Emitter<ChangeEmailState> emit,
  ) async {
    emit(const ChangeEmailLoading());
    final user = await _repository.restoreSession();
    emit(
      user == null
          ? ChangeEmailLoadFailed(AuthFailure(AuthFailureCode.notAuthenticated))
          : ChangeEmailForm(currentEmail: user.email, newEmail: user.email),
    );
  }

  /// Editing a field clears its own server error, and the banner.
  void _onEmailChanged(
    ChangeEmailEmailChanged event,
    Emitter<ChangeEmailState> emit,
  ) {
    final form = state;
    if (form is! ChangeEmailForm || form.isSaving) return;
    emit(
      ChangeEmailForm(
        currentEmail: form.currentEmail,
        newEmail: event.email,
        password: form.password,
        passwordError: form.passwordError,
      ),
    );
  }

  void _onPasswordChanged(
    ChangeEmailPasswordChanged event,
    Emitter<ChangeEmailState> emit,
  ) {
    final form = state;
    if (form is! ChangeEmailForm || form.isSaving) return;
    emit(
      ChangeEmailForm(
        currentEmail: form.currentEmail,
        newEmail: form.newEmail,
        password: event.password,
        emailError: form.emailError,
      ),
    );
  }

  Future<void> _onSubmitted(
    ChangeEmailSubmitted event,
    Emitter<ChangeEmailState> emit,
  ) async {
    final form = state;
    if (form is! ChangeEmailForm || !form.canSave) return;
    emit(_with(form, ChangeEmailStatus.saving));
    try {
      await _repository.changeEmail(
        newEmail: form.trimmedEmail,
        currentPassword: form.password,
      );
      emit(_with(form, ChangeEmailStatus.saved));
    } on AuthFailure catch (failure) {
      emit(_failed(form, failure));
    }
  }

  ChangeEmailForm _with(ChangeEmailForm form, ChangeEmailStatus status) =>
      ChangeEmailForm(
        currentEmail: form.currentEmail,
        newEmail: form.newEmail,
        password: form.password,
        status: status,
      );

  /// Puts each error where the user can fix it: the wrong password under
  /// Current Password, the email problems under the email, the rest in the
  /// banner.
  ChangeEmailForm _failed(ChangeEmailForm form, AuthFailure failure) {
    final fields = failure.fieldErrors;
    final emailError = failure.code == AuthFailureCode.emailTaken
        ? failure.message
        : fields['new_email'];
    final passwordError = failure.code == AuthFailureCode.incorrectPassword
        ? failure.message
        : fields['current_password'];
    final other = [
      for (final entry in fields.entries)
        if (entry.key != 'new_email' && entry.key != 'current_password')
          entry.value,
    ];
    return ChangeEmailForm(
      currentEmail: form.currentEmail,
      newEmail: form.newEmail,
      password: form.password,
      emailError: emailError,
      passwordError: passwordError,
      banner: other.isNotEmpty
          ? other.join(' ')
          : emailError == null && passwordError == null
          ? failure.messageWithWait
          : null,
    );
  }
}

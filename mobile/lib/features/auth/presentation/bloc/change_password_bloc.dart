import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

part 'change_password_event.dart';
part 'change_password_state.dart';

/// The Password form. A factory bloc created in the route, so it closes with
/// the page.
///
/// It never touches `AuthBloc`: the repository stores the new token pair
/// before `changePassword` returns, and the user does not change.
@injectable
class ChangePasswordBloc
    extends Bloc<ChangePasswordEvent, ChangePasswordState> {
  ChangePasswordBloc(this._repository) : super(const ChangePasswordState()) {
    on<ChangePasswordCurrentChanged>(_onCurrentChanged);
    on<ChangePasswordNewChanged>(_onNewChanged);
    on<ChangePasswordConfirmChanged>(_onConfirmChanged);
    on<ChangePasswordSubmitted>(_onSubmitted);
  }

  final AuthRepository _repository;

  /// Editing a field clears its own server error, and the banner.
  void _onCurrentChanged(
    ChangePasswordCurrentChanged event,
    Emitter<ChangePasswordState> emit,
  ) {
    final form = state;
    if (form.isSaving) return;
    emit(
      ChangePasswordState(
        current: event.password,
        newPassword: form.newPassword,
        confirm: form.confirm,
        newError: form.newError,
      ),
    );
  }

  void _onNewChanged(
    ChangePasswordNewChanged event,
    Emitter<ChangePasswordState> emit,
  ) {
    final form = state;
    if (form.isSaving) return;
    emit(
      ChangePasswordState(
        current: form.current,
        newPassword: event.password,
        confirm: form.confirm,
        currentError: form.currentError,
      ),
    );
  }

  void _onConfirmChanged(
    ChangePasswordConfirmChanged event,
    Emitter<ChangePasswordState> emit,
  ) {
    final form = state;
    if (form.isSaving) return;
    emit(
      ChangePasswordState(
        current: form.current,
        newPassword: form.newPassword,
        confirm: event.password,
        currentError: form.currentError,
        newError: form.newError,
      ),
    );
  }

  Future<void> _onSubmitted(
    ChangePasswordSubmitted event,
    Emitter<ChangePasswordState> emit,
  ) async {
    final form = state;
    if (!form.canSave) return;
    emit(_with(form, ChangePasswordStatus.saving));
    try {
      await _repository.changePassword(
        currentPassword: form.current,
        newPassword: form.newPassword,
      );
      emit(_with(form, ChangePasswordStatus.saved));
    } on AuthFailure catch (failure) {
      emit(_failed(form, failure));
    } on Object {
      // For example the secure storage failing after a 200: go back to
      // editing instead of staying on "saving".
      emit(_failed(form, AuthFailure(AuthFailureCode.unknown)));
    }
  }

  ChangePasswordState _with(
    ChangePasswordState form,
    ChangePasswordStatus status,
  ) => ChangePasswordState(
    current: form.current,
    newPassword: form.newPassword,
    confirm: form.confirm,
    status: status,
  );

  /// Puts each error where the user can fix it: the wrong password under
  /// Current Password, the rule problems under New Password, the rest in the
  /// banner.
  ChangePasswordState _failed(ChangePasswordState form, AuthFailure failure) {
    final fields = failure.fieldErrors;
    final currentError = failure.code == AuthFailureCode.incorrectPassword
        ? failure.message
        : fields['current_password'];
    final newError = fields['new_password'];
    final other = [
      for (final entry in fields.entries)
        if (entry.key != 'new_password' && entry.key != 'current_password')
          entry.value,
    ];
    return ChangePasswordState(
      current: form.current,
      newPassword: form.newPassword,
      confirm: form.confirm,
      currentError: currentError,
      newError: newError,
      banner: other.isNotEmpty
          ? other.join(' ')
          : currentError == null && newError == null
          ? failure.messageWithWait
          : null,
    );
  }
}

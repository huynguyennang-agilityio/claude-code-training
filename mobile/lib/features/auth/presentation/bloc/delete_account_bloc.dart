import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

part 'delete_account_event.dart';
part 'delete_account_state.dart';

/// The Delete Account form. A factory bloc created in the route, so it closes
/// with the page.
///
/// It never touches `AuthBloc`: on success the repository announces
/// `accountDeleted` and `AuthBloc` picks it up; the router redirect then shows
/// the sign-in page.
@injectable
class DeleteAccountBloc extends Bloc<DeleteAccountEvent, DeleteAccountState> {
  DeleteAccountBloc(this._repository) : super(const DeleteAccountState()) {
    on<DeleteAccountPasswordChanged>(_onPasswordChanged);
    on<DeleteAccountSubmitted>(_onSubmitted);
  }

  final AuthRepository _repository;

  /// Typing clears the previous error.
  void _onPasswordChanged(
    DeleteAccountPasswordChanged event,
    Emitter<DeleteAccountState> emit,
  ) {
    if (state.isSubmitting || state.status == DeleteAccountStatus.success) {
      return;
    }
    emit(DeleteAccountState(password: event.password));
  }

  Future<void> _onSubmitted(
    DeleteAccountSubmitted event,
    Emitter<DeleteAccountState> emit,
  ) async {
    final current = state;
    if (!current.canSubmit) return;
    emit(
      DeleteAccountState(
        password: current.password,
        status: DeleteAccountStatus.submitting,
      ),
    );
    try {
      await _repository.deleteAccount(currentPassword: current.password);
      emit(
        DeleteAccountState(
          password: current.password,
          status: DeleteAccountStatus.success,
        ),
      );
    } on AuthFailure catch (failure) {
      emit(_failed(current.password, failure));
    } on Object {
      emit(_failed(current.password, AuthFailure(AuthFailureCode.unknown)));
    }
  }

  DeleteAccountState _failed(String password, AuthFailure failure) =>
      DeleteAccountState(
        password: password,
        status: DeleteAccountStatus.failure,
        failure: failure,
      );
}

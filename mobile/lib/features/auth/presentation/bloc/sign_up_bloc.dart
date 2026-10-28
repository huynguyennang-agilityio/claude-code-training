import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

part 'sign_up_event.dart';
part 'sign_up_state.dart';

/// The sign-up form. A factory bloc created in the sign-up route, so it closes
/// with the page.
///
/// The backend signs the new user in. On success the repository announces the
/// new session and the app-wide `AuthBloc` picks it up; the router redirect
/// then leaves the page.
@injectable
class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  SignUpBloc(this._repository) : super(const SignUpInitial()) {
    on<SignUpSubmitted>(_onSubmitted);
  }

  final AuthRepository _repository;

  Future<void> _onSubmitted(
    SignUpSubmitted event,
    Emitter<SignUpState> emit,
  ) async {
    emit(const SignUpInProgress());
    try {
      await _repository.signUp(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );
      emit(const SignUpSucceeded());
    } on AuthFailure catch (failure) {
      emit(SignUpFailed(failure));
    }
  }
}

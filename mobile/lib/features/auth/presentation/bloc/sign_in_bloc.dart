import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

part 'sign_in_event.dart';
part 'sign_in_state.dart';

/// The sign-in form. A factory bloc created in the sign-in route, so it closes
/// with the page.
///
/// On success the repository announces the new session and the app-wide
/// `AuthBloc` picks it up; the router redirect then leaves the page.
@injectable
class SignInBloc extends Bloc<SignInEvent, SignInState> {
  SignInBloc(this._repository) : super(const SignInInitial()) {
    on<SignInSubmitted>(_onSubmitted);
  }

  final AuthRepository _repository;

  Future<void> _onSubmitted(
    SignInSubmitted event,
    Emitter<SignInState> emit,
  ) async {
    emit(const SignInInProgress());
    try {
      await _repository.signIn(email: event.email, password: event.password);
      emit(const SignInSucceeded());
    } on AuthFailure catch (failure) {
      emit(SignInFailed(failure));
    }
  }
}

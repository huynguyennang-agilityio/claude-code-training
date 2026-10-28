part of 'sign_in_bloc.dart';

sealed class SignInState extends Equatable {
  const SignInState();

  @override
  List<Object?> get props => [];
}

final class SignInInitial extends SignInState {
  const SignInInitial();
}

/// The request is running.
final class SignInInProgress extends SignInState {
  const SignInInProgress();
}

final class SignInFailed extends SignInState {
  const SignInFailed(this.failure);

  final AuthFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// Signed in. The page does nothing with this: the router redirect leaves it.
final class SignInSucceeded extends SignInState {
  const SignInSucceeded();
}

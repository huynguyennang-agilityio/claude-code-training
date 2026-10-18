part of 'sign_up_bloc.dart';

sealed class SignUpState extends Equatable {
  const SignUpState();

  @override
  List<Object?> get props => [];
}

final class SignUpInitial extends SignUpState {
  const SignUpInitial();
}

/// The request is running.
final class SignUpInProgress extends SignUpState {
  const SignUpInProgress();
}

final class SignUpFailed extends SignUpState {
  const SignUpFailed(this.failure);

  final AuthFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// Signed up and signed in. The page does nothing with this: the router
/// redirect leaves it.
final class SignUpSucceeded extends SignUpState {
  const SignUpSucceeded();
}

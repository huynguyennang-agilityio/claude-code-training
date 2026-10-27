part of 'change_email_bloc.dart';

sealed class ChangeEmailEvent extends Equatable {
  const ChangeEmailEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened: read the current email to show it.
final class ChangeEmailStarted extends ChangeEmailEvent {
  const ChangeEmailStarted();
}

final class ChangeEmailEmailChanged extends ChangeEmailEvent {
  const ChangeEmailEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

final class ChangeEmailPasswordChanged extends ChangeEmailEvent {
  const ChangeEmailPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// Save (or Done on the keyboard). Ignored unless the form can be saved.
final class ChangeEmailSubmitted extends ChangeEmailEvent {
  const ChangeEmailSubmitted();
}

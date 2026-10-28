part of 'change_password_bloc.dart';

sealed class ChangePasswordEvent extends Equatable {
  const ChangePasswordEvent();

  @override
  List<Object?> get props => [];
}

final class ChangePasswordCurrentChanged extends ChangePasswordEvent {
  const ChangePasswordCurrentChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

final class ChangePasswordNewChanged extends ChangePasswordEvent {
  const ChangePasswordNewChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

final class ChangePasswordConfirmChanged extends ChangePasswordEvent {
  const ChangePasswordConfirmChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// Save (or Done on the keyboard). Ignored unless the form can be saved.
final class ChangePasswordSubmitted extends ChangePasswordEvent {
  const ChangePasswordSubmitted();
}

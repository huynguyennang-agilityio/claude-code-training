part of 'delete_account_bloc.dart';

sealed class DeleteAccountEvent extends Equatable {
  const DeleteAccountEvent();

  @override
  List<Object?> get props => [];
}

final class DeleteAccountPasswordChanged extends DeleteAccountEvent {
  const DeleteAccountPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// The Delete account button (or Done on the keyboard). Ignored unless a
/// password is typed and no request is running.
final class DeleteAccountSubmitted extends DeleteAccountEvent {
  const DeleteAccountSubmitted();
}

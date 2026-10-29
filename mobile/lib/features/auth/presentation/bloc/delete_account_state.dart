part of 'delete_account_bloc.dart';

enum DeleteAccountStatus { idle, submitting, failure, success }

/// The Delete Account form. [failure] is set only in the `failure` status.
final class DeleteAccountState extends Equatable {
  const DeleteAccountState({
    this.password = '',
    this.status = DeleteAccountStatus.idle,
    this.failure,
  });

  final String password;
  final DeleteAccountStatus status;
  final AuthFailure? failure;

  bool get isSubmitting => status == DeleteAccountStatus.submitting;

  /// The button is on when a password is typed and nothing is running or done.
  bool get canSubmit =>
      password.isNotEmpty &&
      (status == DeleteAccountStatus.idle ||
          status == DeleteAccountStatus.failure);

  /// The message for the banner, already worded; null without a failure.
  String? get banner {
    final failure = this.failure;
    if (failure == null) return null;
    if (failure.fieldErrors.isNotEmpty) {
      return failure.fieldErrors.values.join(' ');
    }
    return failure.messageWithWait;
  }

  @override
  List<Object?> get props => [password, status, failure];
}

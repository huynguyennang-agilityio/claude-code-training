part of 'change_password_bloc.dart';

enum ChangePasswordStatus { editing, saving, saved }

/// The Password form. [currentError], [newError] and [banner] are the server
/// messages to show, already worded; the page only displays them.
final class ChangePasswordState extends Equatable {
  const ChangePasswordState({
    this.current = '',
    this.newPassword = '',
    this.confirm = '',
    this.status = ChangePasswordStatus.editing,
    this.currentError,
    this.newError,
    this.banner,
  });

  static const minLength = 8;
  static const maxLength = 128;

  /// The rule of `docs/api/auth.md`, as the hint under New Password.
  static const rule = 'At least 8 characters, with a letter and a digit';

  final String current;
  final String newPassword;
  final String confirm;
  final ChangePasswordStatus status;
  final String? currentError;
  final String? newError;

  /// A problem with the request as a whole, such as `rate_limited`.
  final String? banner;

  bool get isValidNew =>
      newPassword.length >= minLength &&
      newPassword.length <= maxLength &&
      newPassword.contains(RegExp('[A-Za-z]')) &&
      newPassword.contains(RegExp('[0-9]'));

  bool get isSaving => status == ChangePasswordStatus.saving;

  /// Shown while the user has typed a New Password that breaks the rule.
  String? get ruleError => newPassword.isNotEmpty && !isValidNew
      ? 'Password must be 8 to 128 characters with a letter and a digit.'
      : null;

  /// Shown once Confirm Password has text that differs from New Password.
  String? get mismatchError => confirm.isNotEmpty && confirm != newPassword
      ? 'Passwords do not match.'
      : null;

  /// Save is on when all three are filled, the new one is valid and the
  /// confirmation matches.
  bool get canSave =>
      status == ChangePasswordStatus.editing &&
      current.isNotEmpty &&
      isValidNew &&
      confirm == newPassword;

  @override
  List<Object?> get props => [
    current,
    newPassword,
    confirm,
    status,
    currentError,
    newError,
    banner,
  ];
}

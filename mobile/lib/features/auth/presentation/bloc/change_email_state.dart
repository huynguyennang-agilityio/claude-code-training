part of 'change_email_bloc.dart';

sealed class ChangeEmailState extends Equatable {
  const ChangeEmailState();

  @override
  List<Object?> get props => [];
}

/// Reading the current email.
final class ChangeEmailLoading extends ChangeEmailState {
  const ChangeEmailLoading();
}

/// The current email could not be read (no stored session).
final class ChangeEmailLoadFailed extends ChangeEmailState {
  const ChangeEmailLoadFailed(this.failure);

  final AuthFailure failure;

  @override
  List<Object?> get props => [failure];
}

enum ChangeEmailStatus { editing, saving, saved }

/// The Email form. [emailError], [passwordError] and [banner] are the
/// messages to show, already worded; the page only displays them.
final class ChangeEmailForm extends ChangeEmailState {
  const ChangeEmailForm({
    required this.currentEmail,
    required this.newEmail,
    this.password = '',
    this.status = ChangeEmailStatus.editing,
    this.emailError,
    this.passwordError,
    this.banner,
  });

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const maxEmailLength = 254;

  final String currentEmail;
  final String newEmail;
  final String password;
  final ChangeEmailStatus status;
  final String? emailError;
  final String? passwordError;

  /// A problem with the request as a whole, such as `rate_limited`.
  final String? banner;

  String get trimmedEmail => newEmail.trim();

  bool get isValidEmail =>
      trimmedEmail.length <= maxEmailLength &&
      _emailShape.hasMatch(trimmedEmail);

  /// Whether the email differs from the current one (the backend compares
  /// them lowercase).
  bool get isChanged =>
      trimmedEmail.toLowerCase() != currentEmail.trim().toLowerCase();

  bool get isSaving => status == ChangeEmailStatus.saving;

  /// Save is on when the email changed and is valid and a password is typed.
  bool get canSave =>
      status == ChangeEmailStatus.editing &&
      isChanged &&
      isValidEmail &&
      password.isNotEmpty;

  /// Shown while the user has typed something that is not an email.
  String? get formatError => trimmedEmail.isNotEmpty && !isValidEmail
      ? 'Enter a valid email address.'
      : null;

  @override
  List<Object?> get props => [
    currentEmail,
    newEmail,
    password,
    status,
    emailError,
    passwordError,
    banner,
  ];
}

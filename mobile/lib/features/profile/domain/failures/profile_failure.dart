import '../../../../core/error/failure.dart';

/// Why a profile request failed, mapped from the backend's `error.code`
/// (`docs/api/profile.md`, `docs/api/auth.md`).
enum ProfileFailureCode {
  notAuthenticated('not_authenticated', 'Sign in to continue.'),
  invalidToken('invalid_token', 'Your session has expired. Sign in again.'),
  tokenExpired('token_expired', 'Your session has expired. Sign in again.'),
  validation('validation_error', 'Something in your profile is not valid.'),
  network('network', 'Cannot reach StrideQuest. Check your connection.'),
  unknown('unknown', 'Something went wrong. Try again.');

  const ProfileFailureCode(this.wireCode, this.defaultMessage);

  final String wireCode;

  /// A message that is safe to show the user.
  final String defaultMessage;

  static ProfileFailureCode fromWire(String? code) => values.firstWhere(
    (value) => value.wireCode == code,
    orElse: () => unknown,
  );
}

/// A profile request that failed. For [ProfileFailureCode.validation],
/// [fieldErrors] maps the API field name to the backend's message.
class ProfileFailure extends Failure {
  const ProfileFailure(this.code, {this.fieldErrors = const {}});

  final ProfileFailureCode code;
  final Map<String, String> fieldErrors;

  @override
  String get message =>
      fieldErrors.isEmpty ? code.defaultMessage : fieldErrors.values.join(' ');

  @override
  bool operator ==(Object other) =>
      other is ProfileFailure &&
      other.code == code &&
      other.fieldErrors.length == fieldErrors.length &&
      other.fieldErrors.entries.every((e) => fieldErrors[e.key] == e.value);

  @override
  int get hashCode => Object.hash(code, fieldErrors.length);

  @override
  String toString() => 'ProfileFailure(${code.wireCode})';
}

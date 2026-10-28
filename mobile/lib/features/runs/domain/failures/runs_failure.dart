import '../../../../core/error/failure.dart';

/// Why a runs request failed, mapped from the backend's `error.code`
/// (`docs/api/runs.md`).
enum RunsFailureCode {
  invalidCursor('invalid_cursor', 'Something went wrong. Try again.'),
  notAuthenticated('not_authenticated', 'Sign in to continue.'),
  invalidToken('invalid_token', 'Your session has expired. Sign in again.'),
  tokenExpired('token_expired', 'Your session has expired. Sign in again.'),
  validation('validation_error', 'Something in the request is not valid.'),
  network('network', 'Cannot reach StrideQuest. Check your connection.'),
  unknown('unknown', 'Something went wrong. Try again.');

  const RunsFailureCode(this.wireCode, this.defaultMessage);

  final String wireCode;

  /// A message that is safe to show the user.
  final String defaultMessage;

  static RunsFailureCode fromWire(String? code) => values.firstWhere(
    (value) => value.wireCode == code,
    orElse: () => unknown,
  );
}

/// A runs request that failed.
class RunsFailure extends Failure {
  const RunsFailure(this.code);

  final RunsFailureCode code;

  @override
  String get message => code.defaultMessage;

  @override
  bool operator ==(Object other) => other is RunsFailure && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'RunsFailure(${code.wireCode})';
}

/// The health data of the device could not be read.
class HealthFailure extends Failure {
  const HealthFailure();

  @override
  String get message => 'Could not read your health data. Try again.';
}

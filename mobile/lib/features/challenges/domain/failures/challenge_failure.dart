import '../../../../core/error/failure.dart';

/// Why a challenge request failed, mapped from the backend's `error.code`
/// (`docs/api/challenges.md`).
enum ChallengeFailureCode {
  challengeNotFound('challenge_not_found', 'This challenge is not available.'),
  enrollmentNotFound(
    'enrollment_not_found',
    'You are not in this challenge any more.',
  ),
  challengeEnded('challenge_ended', 'This challenge has ended.'),
  alreadyJoined('already_joined', 'You have already joined this challenge.'),
  overlappingChallenge(
    'overlapping_challenge',
    'You are already in a challenge of this type that runs at the same time.',
  ),
  notActive('not_active', 'Only an active challenge can be paused.'),
  challengeNotStarted(
    'challenge_not_started',
    'This challenge has not started yet, so it cannot be paused.',
  ),
  notPaused('not_paused', 'Only a paused challenge can be resumed.'),
  notAuthenticated('not_authenticated', 'Sign in to continue.'),
  invalidToken('invalid_token', 'Your session has expired. Sign in again.'),
  tokenExpired('token_expired', 'Your session has expired. Sign in again.'),
  validation('validation_error', 'Something in the request is not valid.'),
  network('network', 'Cannot reach StrideQuest. Check your connection.'),
  unknown('unknown', 'Something went wrong. Try again.');

  const ChallengeFailureCode(this.wireCode, this.defaultMessage);

  final String wireCode;

  /// A message that is safe to show the user.
  final String defaultMessage;

  static ChallengeFailureCode fromWire(String? code) => values.firstWhere(
    (value) => value.wireCode == code,
    orElse: () => unknown,
  );
}

/// A challenge request that failed. [serverMessage] is the backend's own words
/// (for example the overlap message that names the other challenge); it is
/// shown in place of the default when there is one.
class ChallengeFailure extends Failure {
  const ChallengeFailure(this.code, {this.serverMessage});

  final ChallengeFailureCode code;
  final String? serverMessage;

  @override
  String get message => serverMessage ?? code.defaultMessage;

  @override
  bool operator ==(Object other) =>
      other is ChallengeFailure &&
      other.code == code &&
      other.serverMessage == serverMessage;

  @override
  int get hashCode => Object.hash(code, serverMessage);

  @override
  String toString() => 'ChallengeFailure(${code.wireCode})';
}

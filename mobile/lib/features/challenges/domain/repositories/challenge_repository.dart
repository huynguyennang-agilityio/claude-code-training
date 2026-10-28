import '../entities/challenge.dart';

/// The challenge catalog and the caller's own place in it. Every method throws
/// `ChallengeFailure` on error.
abstract interface class ChallengeRepository {
  /// One page of the published challenges, oldest first. Pass the previous
  /// page's `nextCursor` as [cursor] for the next one.
  Future<ChallengePage> list({
    ChallengeType? type,
    String? query,
    String? cursor,
    int limit,
  });

  Future<Challenge> get(int id);

  /// Join, pause, resume or leave challenge [id]. Each answers with the
  /// challenge as the caller now sees it, so a screen can redraw from it.
  /// Failures: `challengeEnded`, `alreadyJoined`, `overlappingChallenge`
  /// (its message names the other challenge), `enrollmentNotFound`,
  /// `notActive`, `notPaused`, `challengeNotFound`.
  Future<Challenge> join(int id);

  Future<Challenge> pause(int id);

  Future<Challenge> resume(int id);

  Future<Challenge> leave(int id);
}

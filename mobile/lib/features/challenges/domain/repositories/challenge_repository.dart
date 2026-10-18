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
}

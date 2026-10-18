part of 'challenges_bloc.dart';

enum ChallengesStatus { loading, ready, failed }

/// The list screen. An empty [items] in [ChallengesStatus.ready] is the empty
/// state ("no challenges match").
final class ChallengesState extends Equatable {
  const ChallengesState({
    this.status = ChallengesStatus.loading,
    this.items = const [],
    this.nextCursor,
    this.type,
    this.query = '',
    this.loadingMore = false,
    this.moreFailed = false,
    this.failure,
    this.joiningId,
    this.notice,
    this.noticeCount = 0,
  });

  final ChallengesStatus status;
  final List<ChallengeSummary> items;
  final String? nextCursor;
  final ChallengeType? type;
  final String query;
  final bool loadingMore;

  /// Loading the next page failed; the list keeps what it has.
  final bool moreFailed;
  final ChallengeFailure? failure;

  /// The card whose Join is running, so it can't be tapped twice.
  final int? joiningId;

  /// Why the last Join was refused, for the page to show. [noticeCount] grows
  /// with every notice, so the same refusal twice is shown twice.
  final ChallengeFailure? notice;
  final int noticeCount;

  bool get isFiltered => type != null || query.isNotEmpty;

  /// Nullable fields use a sentinel so `null` can be set on purpose.
  ChallengesState copyWith({
    ChallengesStatus? status,
    List<ChallengeSummary>? items,
    Object? nextCursor = _keep,
    Object? type = _keep,
    String? query,
    bool? loadingMore,
    bool? moreFailed,
    Object? failure = _keep,
    Object? joiningId = _keep,
    Object? notice = _keep,
    int? noticeCount,
  }) {
    return ChallengesState(
      status: status ?? this.status,
      items: items ?? this.items,
      nextCursor: identical(nextCursor, _keep)
          ? this.nextCursor
          : nextCursor as String?,
      type: identical(type, _keep) ? this.type : type as ChallengeType?,
      query: query ?? this.query,
      loadingMore: loadingMore ?? this.loadingMore,
      moreFailed: moreFailed ?? this.moreFailed,
      failure: identical(failure, _keep)
          ? this.failure
          : failure as ChallengeFailure?,
      joiningId: identical(joiningId, _keep)
          ? this.joiningId
          : joiningId as int?,
      notice: identical(notice, _keep)
          ? this.notice
          : notice as ChallengeFailure?,
      noticeCount: noticeCount ?? this.noticeCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    nextCursor,
    type,
    query,
    loadingMore,
    moreFailed,
    failure,
    joiningId,
    notice,
    noticeCount,
  ];
}

const Object _keep = Object();

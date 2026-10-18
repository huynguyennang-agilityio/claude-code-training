part of 'my_challenges_bloc.dart';

enum MyChallengesStatus { loading, ready, failed }

/// The My Challenges list. An empty [items] in [MyChallengesStatus.ready] is the
/// empty state ("No challenge in progress").
final class MyChallengesState extends Equatable {
  const MyChallengesState({
    this.status = MyChallengesStatus.loading,
    this.items = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.moreFailed = false,
    this.failure,
  });

  final MyChallengesStatus status;
  final List<MyChallenge> items;

  /// Null on the last page.
  final String? nextCursor;
  final bool loadingMore;

  /// Loading the next page failed: the list stays, with a retry.
  final bool moreFailed;
  final RunsFailure? failure;

  MyChallengesState copyWith({
    MyChallengesStatus? status,
    List<MyChallenge>? items,
    Object? nextCursor = _keep,
    bool? loadingMore,
    bool? moreFailed,
    Object? failure = _keep,
  }) => MyChallengesState(
    status: status ?? this.status,
    items: items ?? this.items,
    nextCursor: identical(nextCursor, _keep)
        ? this.nextCursor
        : nextCursor as String?,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailed: moreFailed ?? this.moreFailed,
    failure: identical(failure, _keep) ? this.failure : failure as RunsFailure?,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    nextCursor,
    loadingMore,
    moreFailed,
    failure,
  ];
}

const _keep = Object();

part of 'challenge_detail_bloc.dart';

sealed class ChallengeDetailState extends Equatable {
  const ChallengeDetailState();

  @override
  List<Object?> get props => [];
}

final class ChallengeDetailLoading extends ChallengeDetailState {
  const ChallengeDetailLoading();
}

/// The challenge on screen. [busy] while an action runs; [notice] is the
/// refusal of the last action, for the screen to show once.
final class ChallengeDetailLoaded extends ChallengeDetailState {
  const ChallengeDetailLoaded(this.challenge, {this.busy = false, this.notice});

  final Challenge challenge;
  final bool busy;
  final ChallengeFailure? notice;

  /// `notice` can be cleared on purpose, so it is passed as an object.
  ChallengeDetailLoaded copyWith({bool? busy, Object? notice = _keep}) =>
      ChallengeDetailLoaded(
        challenge,
        busy: busy ?? this.busy,
        notice: identical(notice, _keep)
            ? this.notice
            : notice as ChallengeFailure?,
      );

  @override
  List<Object?> get props => [challenge, busy, notice];
}

const Object _keep = Object();

final class ChallengeDetailFailed extends ChallengeDetailState {
  const ChallengeDetailFailed(this.failure);

  final ChallengeFailure failure;

  @override
  List<Object?> get props => [failure];
}

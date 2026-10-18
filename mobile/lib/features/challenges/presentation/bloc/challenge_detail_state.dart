part of 'challenge_detail_bloc.dart';

sealed class ChallengeDetailState extends Equatable {
  const ChallengeDetailState();

  @override
  List<Object?> get props => [];
}

final class ChallengeDetailLoading extends ChallengeDetailState {
  const ChallengeDetailLoading();
}

final class ChallengeDetailLoaded extends ChallengeDetailState {
  const ChallengeDetailLoaded(this.challenge);

  final Challenge challenge;

  @override
  List<Object?> get props => [challenge];
}

final class ChallengeDetailFailed extends ChallengeDetailState {
  const ChallengeDetailFailed(this.failure);

  final ChallengeFailure failure;

  @override
  List<Object?> get props => [failure];
}

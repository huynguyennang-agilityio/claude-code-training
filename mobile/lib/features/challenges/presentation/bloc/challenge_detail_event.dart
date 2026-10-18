part of 'challenge_detail_bloc.dart';

sealed class ChallengeDetailEvent extends Equatable {
  const ChallengeDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Load challenge [id] (also the Retry of the error state).
final class ChallengeDetailStarted extends ChallengeDetailEvent {
  const ChallengeDetailStarted(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

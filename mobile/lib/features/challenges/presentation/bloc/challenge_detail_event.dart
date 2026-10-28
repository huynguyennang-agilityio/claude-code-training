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

/// What the caller can do to their place in a challenge.
enum ChallengeAction { join, pause, resume, leave }

/// The user tapped Join, Pause, Resume or Leave (after confirming).
final class ChallengeActionRequested extends ChallengeDetailEvent {
  const ChallengeActionRequested(this.action);

  final ChallengeAction action;

  @override
  List<Object?> get props => [action];
}

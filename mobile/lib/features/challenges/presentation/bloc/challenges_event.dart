part of 'challenges_bloc.dart';

sealed class ChallengesEvent extends Equatable {
  const ChallengesEvent();

  @override
  List<Object?> get props => [];
}

/// The tab opened (or the user tapped Retry): load the first page.
final class ChallengesStarted extends ChallengesEvent {
  const ChallengesStarted();
}

/// Pull to refresh, or coming back from a challenge: reload without clearing.
final class ChallengesRefreshed extends ChallengesEvent {
  const ChallengesRefreshed();
}

/// The search text or the type chip changed. A null [type] is "All".
final class ChallengesFilterChanged extends ChallengesEvent {
  const ChallengesFilterChanged({this.type, this.query = ''});

  final ChallengeType? type;
  final String query;

  @override
  List<Object?> get props => [type, query];
}

/// The user scrolled near the end (or tapped "Try again" under the list).
final class ChallengesMoreRequested extends ChallengesEvent {
  const ChallengesMoreRequested();
}

/// The Join button of a card was tapped.
final class ChallengesJoinRequested extends ChallengesEvent {
  const ChallengesJoinRequested(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

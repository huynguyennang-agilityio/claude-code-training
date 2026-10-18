part of 'my_challenges_bloc.dart';

sealed class MyChallengesEvent extends Equatable {
  const MyChallengesEvent();

  @override
  List<Object?> get props => [];
}

/// The tab opened, or **Try again**: load the first page.
class MyChallengesStarted extends MyChallengesEvent {
  const MyChallengesStarted();
}

/// Reload the first page and keep the list on screen meanwhile: pull to
/// refresh, the tab shown again, a sync finished.
class MyChallengesRefreshed extends MyChallengesEvent {
  const MyChallengesRefreshed();
}

/// The end of the list came into view: load the next page.
class MyChallengesMoreRequested extends MyChallengesEvent {
  const MyChallengesMoreRequested();
}

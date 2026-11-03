part of 'health_notice_bloc.dart';

sealed class HealthNoticeEvent extends Equatable {
  const HealthNoticeEvent();

  @override
  List<Object?> get props => [];
}

/// The screen opened: work out which notice to show, without asking.
class HealthNoticeStarted extends HealthNoticeEvent {
  const HealthNoticeStarted();
}

/// The app came back to the foreground (maybe from Settings): check again.
class HealthNoticeRefreshed extends HealthNoticeEvent {
  const HealthNoticeRefreshed();
}

/// The user tapped **Continue** in the explainer: show the system dialog.
class HealthNoticeAccessRequested extends HealthNoticeEvent {
  const HealthNoticeAccessRequested();
}

/// The user tapped **Open settings**.
class HealthNoticeSettingsRequested extends HealthNoticeEvent {
  const HealthNoticeSettingsRequested();
}

/// The user tapped the banner that asks to install Health Connect.
class HealthNoticeInstallRequested extends HealthNoticeEvent {
  const HealthNoticeInstallRequested();
}

/// The user just joined a challenge: open the explainer, if the notice is
/// askable and it is due. Ignored while an earlier prompt is still pending.
class HealthNoticeJoinPrompted extends HealthNoticeEvent {
  const HealthNoticeJoinPrompted();
}

/// The screen opened the explainer asked for by a join prompt: record it as
/// shown and accept a new prompt.
class HealthNoticeExplainerShown extends HealthNoticeEvent {
  const HealthNoticeExplainerShown();
}

/// The screen could not open the explainer (it is no longer on top): record
/// nothing and accept a new prompt.
class HealthNoticeExplainerSkipped extends HealthNoticeEvent {
  const HealthNoticeExplainerSkipped();
}

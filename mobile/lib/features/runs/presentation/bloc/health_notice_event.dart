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

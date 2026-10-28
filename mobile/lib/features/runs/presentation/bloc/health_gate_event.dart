part of 'health_gate_bloc.dart';

sealed class HealthGateEvent extends Equatable {
  const HealthGateEvent();

  @override
  List<Object?> get props => [];
}

/// The tab opened: find out where access stands, without asking.
class HealthGateStarted extends HealthGateEvent {
  const HealthGateStarted();
}

/// The tab opened again, or the app came back from Settings: check once more.
class HealthGateRechecked extends HealthGateEvent {
  const HealthGateRechecked();
}

/// The user tapped **Allow access**.
class HealthAccessRequested extends HealthGateEvent {
  const HealthAccessRequested();
}

/// The user tapped **Open settings**.
class HealthSettingsRequested extends HealthGateEvent {
  const HealthSettingsRequested();
}

/// The user tapped **Install Health Connect**.
class HealthInstallRequested extends HealthGateEvent {
  const HealthInstallRequested();
}

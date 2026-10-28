part of 'health_gate_bloc.dart';

sealed class HealthGateState extends Equatable {
  const HealthGateState();

  @override
  List<Object?> get props => [];
}

/// Checking, before anything can be shown.
class HealthGateChecking extends HealthGateState {
  const HealthGateChecking();
}

/// Access is known. [busy] while the system dialog is up.
class HealthGateResolved extends HealthGateState {
  const HealthGateResolved(this.access, {this.busy = false});

  final HealthAccess access;
  final bool busy;

  @override
  List<Object?> get props => [access, busy];
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/health_access.dart';
import '../../domain/repositories/health_repository.dart';

part 'health_gate_event.dart';
part 'health_gate_state.dart';

/// The gate of the Active tab: the tab opens only when steps may be read. A
/// factory bloc created in the tab's route.
@injectable
class HealthGateBloc extends Bloc<HealthGateEvent, HealthGateState> {
  HealthGateBloc(this._repository) : super(const HealthGateChecking()) {
    on<HealthGateStarted>(_onStarted);
    on<HealthGateRechecked>(_onRechecked);
    on<HealthAccessRequested>(_onRequested);
    on<HealthSettingsRequested>((event, emit) => _repository.openSettings());
    on<HealthInstallRequested>(
      (event, emit) => _repository.installHealthConnect(),
    );
  }

  final HealthRepository _repository;

  Future<void> _onStarted(
    HealthGateStarted event,
    Emitter<HealthGateState> emit,
  ) async => emit(HealthGateResolved(await _repository.checkAccess()));

  /// Checks again without a spinner, so a tab that is already open does not
  /// flash. A request in progress is left alone.
  Future<void> _onRechecked(
    HealthGateRechecked event,
    Emitter<HealthGateState> emit,
  ) async {
    final current = state;
    if (current is HealthGateResolved && current.busy) return;
    final access = await _repository.checkAccess();
    final now = state;
    if (now is HealthGateResolved && now.busy) return;
    emit(HealthGateResolved(access));
  }

  Future<void> _onRequested(
    HealthAccessRequested event,
    Emitter<HealthGateState> emit,
  ) async {
    final current = state;
    if (current is! HealthGateResolved || current.busy) return;
    emit(HealthGateResolved(current.access, busy: true));
    emit(HealthGateResolved(await _repository.requestAccess()));
  }
}

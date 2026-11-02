import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/health_access.dart';
import '../../domain/services/health_sync.dart';

part 'activity_event.dart';
part 'activity_state.dart';

/// The Active tab: today's figures, as the [HealthSync] last found them,
/// and the manual sync. A factory bloc created once access is granted; it does
/// not sync by itself, the service does.
@injectable
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  ActivityBloc(this._service) : super(const ActivityState()) {
    on<ActivityStarted>(_onStarted);
    on<ActivityRefreshRequested>((event, emit) async {
      if (state.busy) return;
      await _service.sync(force: true);
    });
    on<_SyncStateChanged>((event, emit) => emit(_from(event.sync)));
  }

  final HealthSync _service;
  StreamSubscription<HealthSyncState>? _subscription;

  Future<void> _onStarted(
    ActivityStarted event,
    Emitter<ActivityState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = _service.stream.listen((s) => add(_SyncStateChanged(s)));
    final current = _service.state;
    emit(_from(current, allowed: event.allowed));
    // The usual sync: the service skips it when the figures are fresh and
    // the allowed metrics are the ones it last synced.
    if (!current.busy) await _service.sync();
  }

  ActivityState _from(HealthSyncState sync, {Set<HealthMetric>? allowed}) =>
      ActivityState(
        allowed: allowed ?? state.allowed,
        reading: sync.reading,
        busy: sync.busy,
        error: sync.error,
        syncedAt: sync.syncedAt,
      );

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

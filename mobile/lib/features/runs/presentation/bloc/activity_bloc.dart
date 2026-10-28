import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/activity.dart';
import '../../domain/entities/health_access.dart';
import '../../domain/failures/runs_failure.dart';
import '../../domain/usecases/sync_activity.dart';

part 'activity_event.dart';
part 'activity_state.dart';

/// The Active tab: today's figures, and the manual sync. A factory bloc created
/// once access is granted.
@injectable
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  ActivityBloc(this._sync) : super(const ActivityState()) {
    on<ActivityStarted>(
      (event, emit) => _refresh(emit, allowed: event.allowed),
    );
    on<ActivityRefreshRequested>((event, emit) => _refresh(emit));
  }

  final SyncActivity _sync;

  Future<void> _refresh(
    Emitter<ActivityState> emit, {
    Set<HealthMetric>? allowed,
  }) async {
    if (state.busy) return;
    emit(state.copyWith(allowed: allowed, busy: true, clearError: true));
    try {
      final result = await _sync(state.allowed);
      emit(
        state.copyWith(
          reading: result.reading,
          busy: false,
          error: result.failure?.message,
          // The figures reached StrideQuest only when nothing failed.
          syncedAt: result.failure == null ? result.reading.readAt : null,
        ),
      );
    } on HealthFailure catch (failure) {
      // Keep the figures on screen; say why they could not be updated.
      emit(state.copyWith(busy: false, error: failure.message));
    }
  }
}

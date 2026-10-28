import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/activity.dart';
import '../../domain/failures/runs_failure.dart';
import '../../domain/repositories/runs_repository.dart';

part 'my_challenges_event.dart';
part 'my_challenges_state.dart';

/// The My Challenges tab: the challenges the caller is in, with progress, and
/// paging. A factory bloc created with the Active tab.
@injectable
class MyChallengesBloc extends Bloc<MyChallengesEvent, MyChallengesState> {
  MyChallengesBloc(this._repository) : super(const MyChallengesState()) {
    on<MyChallengesStarted>((_, emit) => _loadFirstPage(emit));
    on<MyChallengesRefreshed>((_, emit) => _loadFirstPage(emit, quiet: true));
    on<MyChallengesMoreRequested>(_onMoreRequested);
  }

  final RunsRepository _repository;

  /// Counts requests that replace the list, so the answer to one that a newer
  /// reload has overtaken is dropped.
  int _generation = 0;

  Future<void> _loadFirstPage(
    Emitter<MyChallengesState> emit, {
    bool quiet = false,
  }) async {
    final generation = ++_generation;
    if (!quiet || state.status != MyChallengesStatus.ready) {
      emit(
        state.copyWith(
          status: MyChallengesStatus.loading,
          items: const [],
          nextCursor: null,
          failure: null,
          loadingMore: false,
          moreFailed: false,
        ),
      );
    }
    try {
      final page = await _repository.myChallenges();
      if (generation != _generation) return;
      emit(
        state.copyWith(
          status: MyChallengesStatus.ready,
          items: page.items,
          nextCursor: page.nextCursor,
          failure: null,
          loadingMore: false,
          moreFailed: false,
        ),
      );
    } on RunsFailure catch (failure) {
      if (generation != _generation) return;
      // A quiet refresh that fails leaves the old list in place.
      if (quiet && state.status == MyChallengesStatus.ready) return;
      emit(state.copyWith(status: MyChallengesStatus.failed, failure: failure));
    }
  }

  Future<void> _onMoreRequested(
    MyChallengesMoreRequested event,
    Emitter<MyChallengesState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (state.status != MyChallengesStatus.ready ||
        cursor == null ||
        state.loadingMore) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true, moreFailed: false));
    try {
      final page = await _repository.myChallenges(cursor: cursor);
      if (generation != _generation) return;
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          nextCursor: page.nextCursor,
          loadingMore: false,
        ),
      );
    } on RunsFailure {
      if (generation != _generation) return;
      emit(state.copyWith(loadingMore: false, moreFailed: true));
    }
  }
}

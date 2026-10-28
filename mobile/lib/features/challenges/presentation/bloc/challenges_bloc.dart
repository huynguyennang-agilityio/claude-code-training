import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/challenge.dart';
import '../../domain/failures/challenge_failure.dart';
import '../../domain/repositories/challenge_repository.dart';

part 'challenges_event.dart';
part 'challenges_state.dart';

/// The Challenges tab: the list with its search, type filter and paging.
/// A factory bloc created in the tab's route.
@injectable
class ChallengesBloc extends Bloc<ChallengesEvent, ChallengesState> {
  ChallengesBloc(this._repository) : super(const ChallengesState()) {
    on<ChallengesStarted>((_, emit) => _loadFirstPage(emit));
    on<ChallengesRefreshed>((_, emit) => _loadFirstPage(emit, quiet: true));
    on<ChallengesFilterChanged>(_onFilterChanged);
    on<ChallengesMoreRequested>(_onMoreRequested);
    on<ChallengesJoinRequested>(_onJoin);
  }

  final ChallengeRepository _repository;

  /// Counts requests that replace the list, so the answer to one that a newer
  /// filter has overtaken is dropped.
  int _generation = 0;

  Future<void> _onFilterChanged(
    ChallengesFilterChanged event,
    Emitter<ChallengesState> emit,
  ) async {
    final query = event.query.trim();
    if (event.type == state.type && query == state.query) return;
    emit(state.copyWith(type: event.type, query: query));
    await _loadFirstPage(emit);
  }

  /// Loads the first page of the current filter. [quiet] keeps the list on
  /// screen while it reloads (pull to refresh, coming back from a detail);
  /// otherwise the loading state shows.
  Future<void> _loadFirstPage(
    Emitter<ChallengesState> emit, {
    bool quiet = false,
  }) async {
    final generation = ++_generation;
    if (!quiet || state.status != ChallengesStatus.ready) {
      emit(
        state.copyWith(
          status: ChallengesStatus.loading,
          items: const [],
          nextCursor: null,
          failure: null,
        ),
      );
    }
    try {
      final page = await _repository.list(type: state.type, query: state.query);
      if (generation != _generation) return;
      emit(
        state.copyWith(
          status: ChallengesStatus.ready,
          items: page.items,
          nextCursor: page.nextCursor,
          failure: null,
        ),
      );
    } on ChallengeFailure catch (failure) {
      if (generation != _generation) return;
      // A quiet refresh that fails leaves the old list in place.
      if (quiet && state.status == ChallengesStatus.ready) return;
      emit(state.copyWith(status: ChallengesStatus.failed, failure: failure));
    }
  }

  /// Joins from a card. On success the card shows Joined; a refusal (it
  /// overlaps another challenge, it ended) is a notice, and the list reloads
  /// quietly so the cards are up to date.
  Future<void> _onJoin(
    ChallengesJoinRequested event,
    Emitter<ChallengesState> emit,
  ) async {
    if (state.joiningId != null) return;
    emit(state.copyWith(joiningId: event.id, notice: null));
    try {
      final joined = (await _repository.join(event.id)).toSummary();
      emit(
        state.copyWith(
          joiningId: null,
          items: [
            for (final item in state.items)
              if (item.id == joined.id) joined else item,
          ],
        ),
      );
    } on ChallengeFailure catch (failure) {
      emit(
        state.copyWith(
          joiningId: null,
          notice: failure,
          noticeCount: state.noticeCount + 1,
        ),
      );
      await _loadFirstPage(emit, quiet: true);
    }
  }

  Future<void> _onMoreRequested(
    ChallengesMoreRequested event,
    Emitter<ChallengesState> emit,
  ) async {
    final cursor = state.nextCursor;
    if (state.status != ChallengesStatus.ready ||
        cursor == null ||
        state.loadingMore) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true, moreFailed: false));
    try {
      final page = await _repository.list(
        type: state.type,
        query: state.query,
        cursor: cursor,
      );
      if (generation != _generation) return;
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          nextCursor: page.nextCursor,
          loadingMore: false,
        ),
      );
    } on ChallengeFailure {
      if (generation != _generation) return;
      emit(state.copyWith(loadingMore: false, moreFailed: true));
    }
  }
}

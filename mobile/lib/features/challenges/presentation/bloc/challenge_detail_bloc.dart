import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/challenge.dart';
import '../../domain/failures/challenge_failure.dart';
import '../../domain/repositories/challenge_repository.dart';

part 'challenge_detail_event.dart';
part 'challenge_detail_state.dart';

/// One challenge's detail screen, and the caller's actions on it (join, pause,
/// resume, leave). A factory bloc created in the detail route, which passes the
/// id from the path (never an object).
@injectable
class ChallengeDetailBloc
    extends Bloc<ChallengeDetailEvent, ChallengeDetailState> {
  ChallengeDetailBloc(this._repository)
    : super(const ChallengeDetailLoading()) {
    on<ChallengeDetailStarted>(_onStarted);
    on<ChallengeActionRequested>(_onAction);
  }

  final ChallengeRepository _repository;

  Future<void> _onStarted(
    ChallengeDetailStarted event,
    Emitter<ChallengeDetailState> emit,
  ) async {
    emit(const ChallengeDetailLoading());
    try {
      emit(ChallengeDetailLoaded(await _repository.get(event.id)));
    } on ChallengeFailure catch (failure) {
      emit(ChallengeDetailFailed(failure));
    }
  }

  Future<void> _onAction(
    ChallengeActionRequested event,
    Emitter<ChallengeDetailState> emit,
  ) async {
    final current = state;
    if (current is! ChallengeDetailLoaded || current.busy) return;
    final id = current.challenge.id;
    emit(current.copyWith(busy: true, notice: null));
    try {
      final updated = await switch (event.action) {
        ChallengeAction.join => _repository.join(id),
        ChallengeAction.pause => _repository.pause(id),
        ChallengeAction.resume => _repository.resume(id),
        ChallengeAction.leave => _repository.leave(id),
      };
      emit(ChallengeDetailLoaded(updated));
    } on ChallengeFailure catch (failure) {
      // Say why, then bring the screen up to date: the refusal usually means
      // it was out of date (someone joined another challenge, it ended).
      emit(current.copyWith(busy: false, notice: failure));
      try {
        final fresh = await _repository.get(id);
        emit(ChallengeDetailLoaded(fresh, notice: failure));
      } on ChallengeFailure {
        // Keep what is on screen; the notice already says what happened.
      }
    }
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/challenge.dart';
import '../../domain/failures/challenge_failure.dart';
import '../../domain/repositories/challenge_repository.dart';

part 'challenge_detail_event.dart';
part 'challenge_detail_state.dart';

/// One challenge's detail screen. A factory bloc created in the detail route,
/// which passes the id from the path (never an object).
@injectable
class ChallengeDetailBloc
    extends Bloc<ChallengeDetailEvent, ChallengeDetailState> {
  ChallengeDetailBloc(this._repository)
    : super(const ChallengeDetailLoading()) {
    on<ChallengeDetailStarted>(_onStarted);
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
}

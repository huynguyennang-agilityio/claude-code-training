import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';

import 'challenge_fixtures.dart';

/// Registers the blocs the challenge routes ask `getIt` for, built on
/// [repository] (an in-memory one by default). The caller resets `getIt` when
/// the test ends.
void registerChallengeBlocs([ChallengeRepository? repository]) {
  final repo = repository ?? FakeChallengeRepository();
  getIt
    ..registerFactory<ChallengesBloc>(() => ChallengesBloc(repo))
    ..registerFactory<ChallengeDetailBloc>(() => ChallengeDetailBloc(repo));
}

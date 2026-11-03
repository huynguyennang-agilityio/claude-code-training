import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';

import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/repositories/health_repository.dart';
import 'package:stridequest/features/runs/domain/usecases/get_health_notice.dart';

import 'challenge_fixtures.dart';
import 'health_fixtures.dart';

class _NoticeNone extends Mock implements GetHealthNotice {}

/// Registers the blocs the challenge routes ask `getIt` for, built on
/// [repository] (an in-memory one by default). A join also asks `getIt` for the
/// health notice; it answers [HealthNotice.none], so no explainer opens. The caller resets `getIt` when
/// the test ends.
void registerChallengeBlocs([ChallengeRepository? repository]) {
  final repo = repository ?? FakeChallengeRepository();
  getIt
    ..registerFactory<ChallengesBloc>(() => ChallengesBloc(repo))
    ..registerFactory<ChallengeDetailBloc>(() => ChallengeDetailBloc(repo));
  if (!getIt.isRegistered<GetHealthNotice>()) {
    final notice = _NoticeNone();
    when(
      () => notice(clock: any(named: 'clock')),
    ).thenAnswer((_) async => HealthNotice.none);
    getIt.registerSingleton<GetHealthNotice>(notice);
  }
  if (!getIt.isRegistered<HealthRepository>()) {
    getIt.registerSingleton<HealthRepository>(FakeHealthRepository());
  }
}

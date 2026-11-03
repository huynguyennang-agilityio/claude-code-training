import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/repositories/health_repository.dart';
import 'package:stridequest/features/runs/domain/services/health_sync.dart';
import 'package:stridequest/features/runs/domain/usecases/get_health_notice.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_notice_bloc.dart';

import 'challenge_fixtures.dart';
import 'health_fixtures.dart';

class MockGetHealthNotice extends Mock implements GetHealthNotice {}

class MockHealthSync extends Mock implements HealthSync {}

/// A [GetHealthNotice] that answers [HealthNotice.none], so no explainer opens.
MockGetHealthNotice noticeNone() => noticeAnswering(HealthNotice.none);

MockGetHealthNotice noticeAnswering(HealthNotice notice) {
  final mock = MockGetHealthNotice();
  when(() => mock(clock: any(named: 'clock'))).thenAnswer((_) async => notice);
  return mock;
}

/// Registers the blocs the challenge routes ask `getIt` for, built on
/// [repository] (an in-memory one by default). The routes also provide a
/// [HealthNoticeBloc], built on [notice] (answers `none` by default), [health]
/// (a [FakeHealthRepository]) and [sync] (does nothing). The caller resets
/// `getIt` when the test ends.
void registerChallengeBlocs({
  ChallengeRepository? repository,
  GetHealthNotice? notice,
  HealthRepository? health,
  HealthSync? sync,
}) {
  final repo = repository ?? FakeChallengeRepository();
  final getNotice = notice ?? noticeNone();
  final healthRepo = health ?? FakeHealthRepository();
  final healthSync = sync ?? _quietSync();
  getIt
    ..registerFactory<ChallengesBloc>(() => ChallengesBloc(repo))
    ..registerFactory<ChallengeDetailBloc>(() => ChallengeDetailBloc(repo))
    ..registerFactory<HealthNoticeBloc>(
      () => HealthNoticeBloc(getNotice, healthRepo, healthSync),
    );
}

HealthSync _quietSync() {
  final sync = MockHealthSync();
  when(sync.syncNow).thenAnswer((_) async {});
  return sync;
}

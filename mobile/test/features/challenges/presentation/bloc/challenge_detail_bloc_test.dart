import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';
import 'package:stridequest/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';

import '../../../../helpers/challenge_fixtures.dart';

class _MockRepository extends Mock implements ChallengeRepository {}

void main() {
  late _MockRepository repository;
  setUp(() => repository = _MockRepository());

  blocTest<ChallengeDetailBloc, ChallengeDetailState>(
    'loads the challenge by id',
    setUp: () =>
        when(() => repository.get(7)).thenAnswer((_) async => challenge(id: 7)),
    build: () => ChallengeDetailBloc(repository),
    act: (bloc) => bloc.add(const ChallengeDetailStarted(7)),
    expect: () => [
      const ChallengeDetailLoading(),
      ChallengeDetailLoaded(challenge(id: 7)),
    ],
  );

  blocTest<ChallengeDetailBloc, ChallengeDetailState>(
    'a missing challenge is a failure',
    setUp: () => when(
      () => repository.get(7),
    ).thenThrow(const ChallengeFailure(ChallengeFailureCode.challengeNotFound)),
    build: () => ChallengeDetailBloc(repository),
    act: (bloc) => bloc.add(const ChallengeDetailStarted(7)),
    expect: () => [
      const ChallengeDetailLoading(),
      const ChallengeDetailFailed(
        ChallengeFailure(ChallengeFailureCode.challengeNotFound),
      ),
    ],
  );
}

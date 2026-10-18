import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
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

  group('actions', () {
    final open = challenge(id: 7);
    final joined = challenge(id: 7, participants: 814, enrollment: enrolled());
    const refused = ChallengeFailure(
      ChallengeFailureCode.overlappingChallenge,
      serverMessage: 'You are already in “X”.',
    );

    ChallengeDetailBloc loadedBloc() => ChallengeDetailBloc(repository);

    blocTest<ChallengeDetailBloc, ChallengeDetailState>(
      'join answers with the updated challenge',
      setUp: () =>
          when(() => repository.join(7)).thenAnswer((_) async => joined),
      build: loadedBloc,
      seed: () => ChallengeDetailLoaded(open),
      act: (bloc) =>
          bloc.add(const ChallengeActionRequested(ChallengeAction.join)),
      expect: () => [
        ChallengeDetailLoaded(open, busy: true),
        ChallengeDetailLoaded(joined),
      ],
    );

    for (final (action, call) in [
      (ChallengeAction.pause, (ChallengeRepository r) => r.pause(7)),
      (ChallengeAction.resume, (ChallengeRepository r) => r.resume(7)),
      (ChallengeAction.leave, (ChallengeRepository r) => r.leave(7)),
    ]) {
      blocTest<ChallengeDetailBloc, ChallengeDetailState>(
        '${action.name} calls the repository and shows its answer',
        setUp: () => when(() => call(repository)).thenAnswer((_) async => open),
        build: loadedBloc,
        seed: () => ChallengeDetailLoaded(joined),
        act: (bloc) => bloc.add(ChallengeActionRequested(action)),
        verify: (bloc) {
          verify(() => call(repository)).called(1);
          expect(bloc.state, ChallengeDetailLoaded(open));
        },
      );
    }

    blocTest<ChallengeDetailBloc, ChallengeDetailState>(
      'a refusal is a notice, and the screen is brought up to date',
      setUp: () {
        when(() => repository.join(7)).thenThrow(refused);
        when(() => repository.get(7)).thenAnswer(
          (_) async => challenge(
            id: 7,
            blockedBy: const BlockingChallenge(id: 2, title: 'X'),
          ),
        );
      },
      build: loadedBloc,
      seed: () => ChallengeDetailLoaded(open),
      act: (bloc) =>
          bloc.add(const ChallengeActionRequested(ChallengeAction.join)),
      expect: () => [
        ChallengeDetailLoaded(open, busy: true),
        ChallengeDetailLoaded(open, notice: refused),
        ChallengeDetailLoaded(
          challenge(
            id: 7,
            blockedBy: const BlockingChallenge(id: 2, title: 'X'),
          ),
          notice: refused,
        ),
      ],
    );

    blocTest<ChallengeDetailBloc, ChallengeDetailState>(
      'a refusal that cannot reload keeps the screen and the notice',
      setUp: () {
        when(() => repository.join(7)).thenThrow(refused);
        when(
          () => repository.get(7),
        ).thenThrow(const ChallengeFailure(ChallengeFailureCode.network));
      },
      build: loadedBloc,
      seed: () => ChallengeDetailLoaded(open),
      act: (bloc) =>
          bloc.add(const ChallengeActionRequested(ChallengeAction.join)),
      verify: (bloc) =>
          expect(bloc.state, ChallengeDetailLoaded(open, notice: refused)),
    );

    blocTest<ChallengeDetailBloc, ChallengeDetailState>(
      'an action while another runs, or before the challenge is loaded, is ignored',
      build: loadedBloc,
      seed: () => ChallengeDetailLoaded(open, busy: true),
      act: (bloc) =>
          bloc.add(const ChallengeActionRequested(ChallengeAction.join)),
      expect: () => <ChallengeDetailState>[],
      verify: (_) => verifyNever(() => repository.join(any())),
    );

    blocTest<ChallengeDetailBloc, ChallengeDetailState>(
      'an action on the loading screen does nothing',
      build: loadedBloc,
      act: (bloc) =>
          bloc.add(const ChallengeActionRequested(ChallengeAction.leave)),
      expect: () => <ChallengeDetailState>[],
    );
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/presentation/bloc/my_challenges_bloc.dart';
import 'package:stridequest/features/runs/presentation/widgets/my_challenges_tab.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/runs_fixtures.dart';

Widget _tab(MyChallengesState state) {
  final bloc = MockMyChallengesBloc();
  whenListen(
    bloc,
    const Stream<MyChallengesState>.empty(),
    initialState: state,
  );
  return Scaffold(
    appBar: AppBar(title: const Text('Active')),
    body: BlocProvider<MyChallengesBloc>.value(
      value: bloc,
      child: const MyChallengesTab(),
    ),
  );
}

void main() {
  goldenScreen(
    'My Challenges, the list',
    'my_challenges_list',
    _tab(
      MyChallengesState(
        status: MyChallengesStatus.ready,
        items: [
          myChallenge(),
          myChallenge(
            id: 9,
            title: 'Mỹ Khê Bay 20 km',
            type: ChallengeType.swim,
            target: 20000,
            city: 'Đà Nẵng',
            startsAt: DateTime.utc(2026, 11, 1),
            started: false,
          ),
        ],
      ),
    ),
  );
  goldenScreen(
    'My Challenges, empty',
    'my_challenges_empty',
    _tab(const MyChallengesState(status: MyChallengesStatus.ready)),
  );
  goldenScreen(
    'My Challenges, error',
    'my_challenges_error',
    _tab(
      const MyChallengesState(
        status: MyChallengesStatus.failed,
        failure: RunsFailure(RunsFailureCode.network),
      ),
    ),
  );
  goldenScreen(
    'My Challenges, loading',
    'my_challenges_loading',
    _tab(const MyChallengesState()),
    settle: false,
  );
}

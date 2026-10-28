import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenges_page.dart';

import '../../../../helpers/challenge_fixtures.dart';
import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_challenge_blocs.dart';

Widget _page(ChallengesState state) {
  final bloc = MockChallengesBloc();
  whenListen(bloc, const Stream<ChallengesState>.empty(), initialState: state);
  return BlocProvider<ChallengesBloc>.value(
    value: bloc,
    child: const ChallengesPage(),
  );
}

void main() {
  goldenScreen(
    'ChallengesPage',
    'challenges_page',
    _page(
      ChallengesState(
        status: ChallengesStatus.ready,
        items: [
          summary(),
          summary(
            id: 2,
            title: 'Mỹ Khê Bay 20 km',
            type: ChallengeType.swim,
            target: 20000,
            city: 'Đà Nẵng',
            participants: 860,
            enrollment: enrolled(),
          ),
          summary(
            id: 3,
            title: 'Saigon Ride',
            type: ChallengeType.cycle,
            target: 100000,
            enrollment: enrolled(EnrollmentStatus.paused),
          ),
        ],
      ),
    ),
  );
  goldenScreen(
    'ChallengesPage, filtered by type',
    'challenges_page_filtered',
    _page(
      ChallengesState(
        status: ChallengesStatus.ready,
        type: ChallengeType.swim,
        items: [
          summary(id: 2, title: 'Mỹ Khê Bay 20 km', type: ChallengeType.swim),
        ],
      ),
    ),
  );
  goldenScreen(
    'ChallengesPage, loading',
    'challenges_page_loading',
    _page(const ChallengesState()),
    settle: false,
  );
  goldenScreen(
    'ChallengesPage, empty',
    'challenges_page_empty',
    _page(const ChallengesState(status: ChallengesStatus.ready, query: 'zzz')),
  );
  goldenScreen(
    'ChallengesPage, error',
    'challenges_page_error',
    _page(
      const ChallengesState(
        status: ChallengesStatus.failed,
        failure: ChallengeFailure(ChallengeFailureCode.network),
      ),
    ),
  );
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import 'package:stridequest/features/challenges/presentation/pages/challenge_detail_page.dart';

import '../../../../helpers/challenge_fixtures.dart';
import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/mock_challenge_blocs.dart';

final _now = DateTime.utc(2026, 10, 17, 12, 46, 53);

Widget _page(ChallengeDetailState state, {DateTime? now}) {
  final bloc = MockChallengeDetailBloc();
  whenListen(
    bloc,
    const Stream<ChallengeDetailState>.empty(),
    initialState: state,
  );
  return BlocProvider<ChallengeDetailBloc>.value(
    value: bloc,
    child: ChallengeDetailPage(challengeId: 1, clock: () => now ?? _now),
  );
}

void main() {
  goldenScreen(
    'ChallengeDetailPage, open',
    'challenge_detail_page_open',
    _page(ChallengeDetailLoaded(challenge())),
  );
  goldenScreen(
    'ChallengeDetailPage, upcoming',
    'challenge_detail_page_upcoming',
    _page(
      ChallengeDetailLoaded(challenge(startsAt: DateTime.utc(2026, 10, 20))),
    ),
  );
  goldenScreen(
    'ChallengeDetailPage, ended',
    'challenge_detail_page_ended',
    _page(ChallengeDetailLoaded(challenge()), now: DateTime.utc(2026, 11, 2)),
  );
  goldenScreen(
    'ChallengeDetailPage, loading',
    'challenge_detail_page_loading',
    _page(const ChallengeDetailLoading()),
    settle: false,
  );
  goldenScreen(
    'ChallengeDetailPage, error',
    'challenge_detail_page_error',
    _page(
      const ChallengeDetailFailed(
        ChallengeFailure(ChallengeFailureCode.challengeNotFound),
      ),
    ),
  );
  goldenScreen(
    'ChallengeDetailPage, joined',
    'challenge_detail_page_joined',
    _page(
      ChallengeDetailLoaded(
        challenge(
          type: ChallengeType.swim,
          target: 20000,
          title: 'Mỹ Khê Bay 20 km',
          enrollment: enrolled(),
        ),
      ),
    ),
  );
  goldenScreen(
    'ChallengeDetailPage, joined, not started',
    'challenge_detail_page_joined_not_started',
    _page(
      ChallengeDetailLoaded(
        challenge(startsAt: DateTime.utc(2026, 10, 20), enrollment: enrolled()),
      ),
    ),
  );
  goldenScreen(
    'ChallengeDetailPage, paused',
    'challenge_detail_page_paused',
    _page(
      ChallengeDetailLoaded(
        challenge(enrollment: enrolled(EnrollmentStatus.paused)),
      ),
    ),
  );
  goldenScreen(
    'ChallengeDetailPage, blocked by an overlapping challenge',
    'challenge_detail_page_blocked',
    _page(
      ChallengeDetailLoaded(
        challenge(
          title: 'Hanoi Autumn 30K Steps',
          blockedBy: const BlockingChallenge(
            id: 2,
            title: 'Old Quarter 50K Steps',
          ),
        ),
      ),
    ),
  );
}

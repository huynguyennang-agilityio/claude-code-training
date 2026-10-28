import 'package:bloc_test/bloc_test.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenge_detail_bloc.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';

class MockChallengesBloc extends MockBloc<ChallengesEvent, ChallengesState>
    implements ChallengesBloc {}

class MockChallengeDetailBloc
    extends MockBloc<ChallengeDetailEvent, ChallengeDetailState>
    implements ChallengeDetailBloc {}

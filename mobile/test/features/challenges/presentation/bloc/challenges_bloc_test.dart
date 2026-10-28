import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/failures/challenge_failure.dart';
import 'package:stridequest/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:stridequest/features/challenges/presentation/bloc/challenges_bloc.dart';

import '../../../../helpers/challenge_fixtures.dart';

class _MockRepository extends Mock implements ChallengeRepository {}

void main() {
  late _MockRepository repository;
  final first = summary();
  final second = summary(id: 2, title: 'Mỹ Khê Bay 20 km');
  const offline = ChallengeFailure(ChallengeFailureCode.network);

  setUp(() => repository = _MockRepository());

  void stubList({
    ChallengeType? type,
    String? query,
    String? cursor,
    required Object answer,
  }) {
    final call = when(
      () => repository.list(type: type, query: query, cursor: cursor),
    );
    if (answer is Exception) {
      call.thenThrow(answer);
    } else {
      call.thenAnswer((_) async => answer as ChallengePage);
    }
  }

  blocTest<ChallengesBloc, ChallengesState>(
    'starts by loading the first page',
    setUp: () => stubList(
      query: '',
      answer: ChallengePage(items: [first, second], nextCursor: 'c1'),
    ),
    build: () => ChallengesBloc(repository),
    act: (bloc) => bloc.add(const ChallengesStarted()),
    expect: () => [
      const ChallengesState(),
      ChallengesState(
        status: ChallengesStatus.ready,
        items: [first, second],
        nextCursor: 'c1',
      ),
    ],
  );

  blocTest<ChallengesBloc, ChallengesState>(
    'an empty list is the ready state with no items',
    setUp: () => stubList(
      query: '',
      answer: const ChallengePage(items: []),
    ),
    build: () => ChallengesBloc(repository),
    act: (bloc) => bloc.add(const ChallengesStarted()),
    verify: (bloc) {
      expect(bloc.state.status, ChallengesStatus.ready);
      expect(bloc.state.items, isEmpty);
    },
  );

  blocTest<ChallengesBloc, ChallengesState>(
    'a failed load shows the failure, and starting again retries',
    setUp: () => stubList(query: '', answer: offline),
    build: () => ChallengesBloc(repository),
    act: (bloc) => bloc.add(const ChallengesStarted()),
    expect: () => [
      const ChallengesState(),
      const ChallengesState(status: ChallengesStatus.failed, failure: offline),
    ],
  );

  blocTest<ChallengesBloc, ChallengesState>(
    'a filter reloads from the first page with the type and the trimmed text',
    setUp: () => stubList(
      type: ChallengeType.swim,
      query: 'bay',
      answer: ChallengePage(items: [second]),
    ),
    build: () => ChallengesBloc(repository),
    act: (bloc) => bloc.add(
      const ChallengesFilterChanged(type: ChallengeType.swim, query: '  bay '),
    ),
    verify: (bloc) {
      expect(bloc.state.items, [second]);
      expect(bloc.state.type, ChallengeType.swim);
      expect(bloc.state.query, 'bay');
      expect(bloc.state.isFiltered, isTrue);
      verify(
        () => repository.list(
          type: ChallengeType.swim,
          query: 'bay',
          cursor: null,
        ),
      ).called(1);
    },
  );

  blocTest<ChallengesBloc, ChallengesState>(
    'the same filter again does nothing',
    build: () => ChallengesBloc(repository),
    act: (bloc) => bloc.add(const ChallengesFilterChanged()),
    expect: () => <ChallengesState>[],
  );

  blocTest<ChallengesBloc, ChallengesState>(
    'more appends the next page and ends without a cursor',
    setUp: () {
      stubList(
        query: '',
        answer: ChallengePage(items: [first], nextCursor: 'c1'),
      );
      stubList(
        query: '',
        cursor: 'c1',
        answer: ChallengePage(items: [second]),
      );
    },
    build: () => ChallengesBloc(repository),
    act: (bloc) async {
      bloc.add(const ChallengesStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ChallengesMoreRequested());
    },
    verify: (bloc) {
      expect(bloc.state.items, [first, second]);
      expect(bloc.state.nextCursor, isNull);
      expect(bloc.state.loadingMore, isFalse);
    },
  );

  blocTest<ChallengesBloc, ChallengesState>(
    'more does nothing on the last page',
    setUp: () => stubList(
      query: '',
      answer: ChallengePage(items: [first]),
    ),
    build: () => ChallengesBloc(repository),
    act: (bloc) async {
      bloc.add(const ChallengesStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ChallengesMoreRequested());
    },
    verify: (bloc) => verify(() => repository.list(query: '')).called(1),
  );

  blocTest<ChallengesBloc, ChallengesState>(
    'a failed next page keeps the list and says so',
    setUp: () {
      stubList(
        query: '',
        answer: ChallengePage(items: [first], nextCursor: 'c1'),
      );
      stubList(query: '', cursor: 'c1', answer: offline);
    },
    build: () => ChallengesBloc(repository),
    act: (bloc) async {
      bloc.add(const ChallengesStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ChallengesMoreRequested());
    },
    verify: (bloc) {
      expect(bloc.state.status, ChallengesStatus.ready);
      expect(bloc.state.items, [first]);
      expect(bloc.state.moreFailed, isTrue);
      expect(bloc.state.nextCursor, 'c1');
    },
  );

  blocTest<ChallengesBloc, ChallengesState>(
    'a refresh keeps the list on screen while it reloads',
    setUp: () => stubList(
      query: '',
      answer: ChallengePage(items: [first, second]),
    ),
    build: () => ChallengesBloc(repository),
    seed: () => ChallengesState(status: ChallengesStatus.ready, items: [first]),
    act: (bloc) => bloc.add(const ChallengesRefreshed()),
    expect: () => [
      ChallengesState(status: ChallengesStatus.ready, items: [first, second]),
    ],
  );

  blocTest<ChallengesBloc, ChallengesState>(
    'a refresh that fails leaves the list alone',
    setUp: () => stubList(query: '', answer: offline),
    build: () => ChallengesBloc(repository),
    seed: () => ChallengesState(status: ChallengesStatus.ready, items: [first]),
    act: (bloc) => bloc.add(const ChallengesRefreshed()),
    expect: () => <ChallengesState>[],
  );

  test('the answer to an overtaken filter is dropped', () async {
    final slow = Completer<ChallengePage>();
    when(
      () => repository.list(type: null, query: 'a', cursor: null),
    ).thenAnswer((_) => slow.future);
    when(
      () => repository.list(type: null, query: 'ab', cursor: null),
    ).thenAnswer((_) async => ChallengePage(items: [second]));
    final bloc = ChallengesBloc(repository);

    bloc.add(const ChallengesFilterChanged(query: 'a'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const ChallengesFilterChanged(query: 'ab'));
    await Future<void>.delayed(Duration.zero);
    slow.complete(ChallengePage(items: [first]));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items, [second]);
    expect(bloc.state.query, 'ab');
    await bloc.close();
  });

  group('join from a card', () {
    final joinedFirst = challenge(
      id: 1,
      participants: 1235,
      enrollment: enrolled(),
    );
    final ready = ChallengesState(
      status: ChallengesStatus.ready,
      items: [first, second],
    );

    blocTest<ChallengesBloc, ChallengesState>(
      'the card turns into Joined',
      setUp: () =>
          when(() => repository.join(1)).thenAnswer((_) async => joinedFirst),
      build: () => ChallengesBloc(repository),
      seed: () => ready,
      act: (bloc) => bloc.add(const ChallengesJoinRequested(1)),
      verify: (bloc) {
        expect(bloc.state.joiningId, isNull);
        expect(bloc.state.items.first.enrollment, enrolled());
        expect(bloc.state.items.first.participantCount, 1235);
        expect(bloc.state.items.last, second);
      },
    );

    blocTest<ChallengesBloc, ChallengesState>(
      'a refusal is a notice and the list reloads',
      setUp: () {
        when(() => repository.join(1)).thenThrow(
          const ChallengeFailure(
            ChallengeFailureCode.overlappingChallenge,
            serverMessage: 'You are already in “X”.',
          ),
        );
        stubList(
          query: '',
          answer: ChallengePage(items: [first, second]),
        );
      },
      build: () => ChallengesBloc(repository),
      seed: () => ready,
      act: (bloc) => bloc.add(const ChallengesJoinRequested(1)),
      verify: (bloc) {
        expect(bloc.state.joiningId, isNull);
        expect(bloc.state.notice?.message, 'You are already in “X”.');
        expect(bloc.state.noticeCount, 1);
        verify(() => repository.list(query: '')).called(1);
      },
    );

    blocTest<ChallengesBloc, ChallengesState>(
      'a second join while one runs is ignored',
      build: () => ChallengesBloc(repository),
      seed: () => ready.copyWith(joiningId: 1),
      act: (bloc) => bloc.add(const ChallengesJoinRequested(2)),
      expect: () => <ChallengesState>[],
    );
  });
}

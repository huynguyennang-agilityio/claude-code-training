import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/repositories/runs_repository.dart';
import 'package:stridequest/features/runs/presentation/bloc/my_challenges_bloc.dart';

import '../../../../helpers/runs_fixtures.dart';

final _first = myChallenge(id: 1, title: 'First');
final _second = myChallenge(id: 2, title: 'Second');
final _third = myChallenge(id: 3, title: 'Third');
const _network = RunsFailure(RunsFailureCode.network);

/// Answers pages in order; a page can be held back or fail.
class _Pages implements RunsRepository {
  _Pages(this.pages);

  final List<Object> pages;
  final cursors = <String?>[];

  @override
  Future<MyChallengePage> myChallenges({String? cursor, int limit = 20}) async {
    final next = pages[cursors.length];
    cursors.add(cursor);
    if (next is RunsFailure) throw next;
    return next as MyChallengePage;
  }

  @override
  Future<StepSyncResult> syncSteps(List<StepRecord> records) =>
      throw UnimplementedError();

  @override
  Future<void> saveDailyActivity(List<DailyFigures> days) =>
      throw UnimplementedError();

  @override
  Future<DateTime?> earliestRunJoin() => throw UnimplementedError();
}

MyChallengePage _page(List<MyChallenge> items, [String? next]) =>
    MyChallengePage(items: items, nextCursor: next);

void main() {
  blocTest<MyChallengesBloc, MyChallengesState>(
    'starting loads the first page',
    build: () => MyChallengesBloc(
      _Pages([
        _page([_first], 'c1'),
      ]),
    ),
    act: (bloc) => bloc.add(const MyChallengesStarted()),
    expect: () => [
      const MyChallengesState(),
      MyChallengesState(
        status: MyChallengesStatus.ready,
        items: [_first],
        nextCursor: 'c1',
      ),
    ],
  );

  blocTest<MyChallengesBloc, MyChallengesState>(
    'no challenge is an empty ready list',
    build: () => MyChallengesBloc(_Pages([_page([])])),
    act: (bloc) => bloc.add(const MyChallengesStarted()),
    expect: () => [
      const MyChallengesState(),
      const MyChallengesState(status: MyChallengesStatus.ready),
    ],
  );

  blocTest<MyChallengesBloc, MyChallengesState>(
    'a failure on the first load is a failed state, and Try again loads',
    build: () => MyChallengesBloc(
      _Pages([
        _network,
        _page([_first]),
      ]),
    ),
    act: (bloc) async {
      bloc.add(const MyChallengesStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const MyChallengesStarted());
    },
    expect: () => [
      const MyChallengesState(),
      const MyChallengesState(
        status: MyChallengesStatus.failed,
        failure: _network,
      ),
      const MyChallengesState(),
      MyChallengesState(status: MyChallengesStatus.ready, items: [_first]),
    ],
  );

  blocTest<MyChallengesBloc, MyChallengesState>(
    'more appends the next page and ends when there is no cursor',
    build: () => MyChallengesBloc(
      _Pages([
        _page([_second]),
      ]),
    ),
    seed: () => MyChallengesState(
      status: MyChallengesStatus.ready,
      items: [_first],
      nextCursor: 'c1',
    ),
    act: (bloc) => bloc.add(const MyChallengesMoreRequested()),
    expect: () => [
      MyChallengesState(
        status: MyChallengesStatus.ready,
        items: [_first],
        nextCursor: 'c1',
        loadingMore: true,
      ),
      MyChallengesState(
        status: MyChallengesStatus.ready,
        items: [_first, _second],
      ),
    ],
  );

  blocTest<MyChallengesBloc, MyChallengesState>(
    'a failed next page keeps the list and offers a retry',
    build: () => MyChallengesBloc(_Pages([_network])),
    seed: () => MyChallengesState(
      status: MyChallengesStatus.ready,
      items: [_first],
      nextCursor: 'c1',
    ),
    act: (bloc) => bloc.add(const MyChallengesMoreRequested()),
    expect: () => [
      MyChallengesState(
        status: MyChallengesStatus.ready,
        items: [_first],
        nextCursor: 'c1',
        loadingMore: true,
      ),
      MyChallengesState(
        status: MyChallengesStatus.ready,
        items: [_first],
        nextCursor: 'c1',
        moreFailed: true,
      ),
    ],
  );

  blocTest<MyChallengesBloc, MyChallengesState>(
    'more with no next page, or while loading, or before ready, does nothing',
    build: () => MyChallengesBloc(_Pages([])),
    seed: () =>
        MyChallengesState(status: MyChallengesStatus.ready, items: [_first]),
    act: (bloc) => bloc
      ..add(const MyChallengesMoreRequested())
      ..add(const MyChallengesMoreRequested()),
    expect: () => <MyChallengesState>[],
  );

  blocTest<MyChallengesBloc, MyChallengesState>(
    'a quiet refresh keeps the list on screen and replaces it',
    build: () => MyChallengesBloc(
      _Pages([
        _page([_third]),
      ]),
    ),
    seed: () => MyChallengesState(
      status: MyChallengesStatus.ready,
      items: [_first, _second],
      nextCursor: 'c1',
    ),
    act: (bloc) => bloc.add(const MyChallengesRefreshed()),
    expect: () => [
      MyChallengesState(status: MyChallengesStatus.ready, items: [_third]),
    ],
  );

  blocTest<MyChallengesBloc, MyChallengesState>(
    'a quiet refresh that fails leaves the old list',
    build: () => MyChallengesBloc(_Pages([_network])),
    seed: () =>
        MyChallengesState(status: MyChallengesStatus.ready, items: [_first]),
    act: (bloc) => bloc.add(const MyChallengesRefreshed()),
    expect: () => <MyChallengesState>[],
  );

  blocTest<MyChallengesBloc, MyChallengesState>(
    'a refresh before the first load shows the loading state',
    build: () => MyChallengesBloc(
      _Pages([
        _page([_first]),
      ]),
    ),
    act: (bloc) => bloc.add(const MyChallengesRefreshed()),
    expect: () => [
      const MyChallengesState(),
      MyChallengesState(status: MyChallengesStatus.ready, items: [_first]),
    ],
  );
}

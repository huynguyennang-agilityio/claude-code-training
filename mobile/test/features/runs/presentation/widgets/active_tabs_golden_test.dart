import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/bloc/activity_bloc.dart';
import 'package:stridequest/features/runs/presentation/bloc/my_challenges_bloc.dart';
import 'package:stridequest/features/runs/presentation/widgets/active_tabs.dart';
import 'package:stridequest/features/runs/presentation/widgets/activity_tab.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_gate_view.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/health_fixtures.dart';
import '../../../../helpers/runs_fixtures.dart';

const _all = {
  HealthMetric.steps,
  HealthMetric.calories,
  HealthMetric.distance,
  HealthMetric.sleep,
};

final _readAt = DateTime(2026, 10, 19, 21, 55);

Widget _tabs(ActivityState state) {
  final bloc = MockActivityBloc();
  whenListen(bloc, const Stream<ActivityState>.empty(), initialState: state);
  final mine = MockMyChallengesBloc();
  whenListen(
    mine,
    const Stream<MyChallengesState>.empty(),
    initialState: const MyChallengesState(status: MyChallengesStatus.ready),
  );
  return withHealthNotice(
    MultiBlocProvider(
      providers: [
        BlocProvider<ActivityBloc>.value(value: bloc),
        BlocProvider<MyChallengesBloc>.value(value: mine),
      ],
      child: const ActiveTabs(activity: ActivityTab()),
    ),
  );
}

/// The tabs with no health access: the gate in Active, and the notice above
/// the list in My Challenges ([initialIndex] 1).
Widget _noAccess({required int initialIndex}) {
  final mine = MockMyChallengesBloc();
  whenListen(
    mine,
    const Stream<MyChallengesState>.empty(),
    initialState: MyChallengesState(
      status: MyChallengesStatus.ready,
      items: [
        myChallenge(),
        myChallenge(id: 9, title: 'Mỹ Khê Bay 20 km'),
      ],
    ),
  );
  return withHealthNotice(
    BlocProvider<MyChallengesBloc>.value(
      value: mine,
      child: ActiveTabs(
        initialIndex: initialIndex,
        activity: HealthGateView(
          status: HealthAccessStatus.denied,
          busy: false,
          onAction: () {},
        ),
      ),
    ),
    HealthNotice.askable,
  );
}

ActivityReading _reading() => ActivityReading(
  readAt: _readAt,
  steps: 5490,
  calories: 312,
  distanceM: 3080,
  sleepMinutes: 390,
);

void main() {
  // The same pixels as the page's `active_gate_denied` golden, on purpose: the
  // issue asks for both tabs without access as a pair of widget goldens.
  goldenScreen(
    'ActiveTabs, no access, the Active tab',
    'active_tabs_no_access_active',
    _noAccess(initialIndex: 0),
  );
  goldenScreen(
    'ActiveTabs, no access, My Challenges',
    'active_tabs_no_access_my_challenges',
    _noAccess(initialIndex: 1),
  );
  goldenScreen(
    'ActiveTabs, the figures',
    'active_tab_figures',
    _tabs(ActivityState(allowed: _all, reading: _reading(), syncedAt: _readAt)),
  );
  goldenScreen(
    'ActiveTabs, syncing',
    'active_tab_syncing',
    _tabs(ActivityState(allowed: _all, reading: _reading(), busy: true)),
  );
  goldenScreen(
    'ActiveTabs, refused metrics and a sync error',
    'active_tab_refused_and_error',
    _tabs(
      ActivityState(
        allowed: const {HealthMetric.steps, HealthMetric.distance},
        reading: ActivityReading(readAt: _readAt, steps: 5490, distanceM: 3080),
        error: 'Cannot reach StrideQuest. Check your connection.',
      ),
    ),
  );
  goldenScreen(
    'ActiveTabs, first read',
    'active_tab_loading',
    _tabs(const ActivityState(allowed: _all, busy: true)),
  );
}

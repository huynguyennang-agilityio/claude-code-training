import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/bloc/activity_bloc.dart';
import 'package:stridequest/features/runs/presentation/bloc/my_challenges_bloc.dart';
import 'package:stridequest/features/runs/presentation/widgets/active_tabs.dart';

import '../../../../helpers/golden_screen.dart';
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
  return MultiBlocProvider(
    providers: [
      BlocProvider<ActivityBloc>.value(value: bloc),
      BlocProvider<MyChallengesBloc>.value(value: mine),
    ],
    child: const ActiveTabs(),
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

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_gate_bloc.dart';
import 'package:stridequest/features/runs/presentation/pages/active_challenges_page.dart';

import '../../../../helpers/golden_screen.dart';
import '../../../../helpers/health_fixtures.dart';

Widget _page(HealthGateState state) {
  final bloc = MockHealthGateBloc();
  whenListen(bloc, const Stream<HealthGateState>.empty(), initialState: state);
  return BlocProvider<HealthGateBloc>.value(
    value: bloc,
    child: const ActiveChallengesPage(),
  );
}

void main() {
  goldenScreen(
    'ActiveChallengesPage, access not given',
    'active_gate_denied',
    _page(const HealthGateResolved(HealthAccess.denied())),
  );
  goldenScreen(
    'ActiveChallengesPage, access turned off',
    'active_gate_permanently_denied',
    _page(const HealthGateResolved(HealthAccess.permanentlyDenied())),
  );
  goldenScreen(
    'ActiveChallengesPage, Health Connect missing',
    'active_gate_unavailable',
    _page(const HealthGateResolved(HealthAccess.unavailable())),
  );
  goldenScreen(
    'ActiveChallengesPage, checking',
    'active_gate_checking',
    _page(const HealthGateChecking()),
    settle: false,
  );
}

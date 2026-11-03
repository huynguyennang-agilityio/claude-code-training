import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/bloc/activity_bloc.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_gate_bloc.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_notice_bloc.dart';
import 'package:stridequest/features/runs/presentation/bloc/my_challenges_bloc.dart';
import 'package:stridequest/features/runs/presentation/pages/active_challenges_page.dart';
import 'package:stridequest/features/runs/presentation/widgets/activity_tab.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_gate_view.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_metric_list.dart';
import 'package:stridequest/features/runs/presentation/widgets/my_challenges_tab.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/health_fixtures.dart';
import '../../../../helpers/pump_screen.dart';
import '../../../../helpers/runs_fixtures.dart';

const _granted = HealthAccess(
  HealthAccessStatus.granted,
  allowed: {HealthMetric.steps},
);

final _states = <String, HealthGateState>{
  'checking': const HealthGateChecking(),
  'denied': const HealthGateResolved(HealthAccess.denied()),
  'denied, busy': const HealthGateResolved(HealthAccess.denied(), busy: true),
  'permanently denied': const HealthGateResolved(
    HealthAccess.permanentlyDenied(),
  ),
  'unavailable': const HealthGateResolved(HealthAccess.unavailable()),
  'granted': const HealthGateResolved(_granted),
};

Widget _page(HealthGateBloc bloc, {HealthNotice notice = HealthNotice.none}) =>
    withHealthNotice(
      BlocProvider<HealthGateBloc>.value(
        value: bloc,
        child: const ActiveChallengesPage(),
      ),
      notice,
    );

/// The app goes to Settings and comes back, in the order the platform reports
/// it: `AppLifecycleListener` (the banner) asserts on a skipped state.
void _comeBack(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  late MockHealthGateBloc bloc;

  // Access granted builds the tabs, whose bloc comes from `getIt` as in the app.
  setUp(() {
    final activity = MockActivityBloc();
    whenListen(
      activity,
      const Stream<ActivityState>.empty(),
      initialState: ActivityState(
        allowed: const {HealthMetric.steps},
        reading: ActivityReading(readAt: DateTime(2026, 10, 19, 21, 55)),
      ),
    );
    getIt.registerFactory<ActivityBloc>(() => activity);
    final mine = MockMyChallengesBloc();
    whenListen(
      mine,
      const Stream<MyChallengesState>.empty(),
      initialState: const MyChallengesState(status: MyChallengesStatus.ready),
    );
    getIt.registerFactory<MyChallengesBloc>(() => mine);
    addTearDown(getIt.reset);
  });

  MockHealthGateBloc blocIn(HealthGateState state) {
    final mock = MockHealthGateBloc();
    whenListen(
      mock,
      const Stream<HealthGateState>.empty(),
      initialState: state,
    );
    return mock;
  }

  group('the gate', () {
    testWidgets('denied explains why and offers Allow access', (tester) async {
      bloc = blocIn(const HealthGateResolved(HealthAccess.denied()));
      await pumpScreen(tester, _page(bloc));

      expect(find.text('Allow health access'), findsOneWidget);
      expect(find.textContaining('cannot track your progress'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Optional'), findsNWidgets(3));
      expect(find.text(healthConsentNote), findsOneWidget);

      await tester.ensureVisible(find.text('Allow access'));
      await tester.tap(find.text('Allow access'));

      verify(() => bloc.add(const HealthAccessRequested())).called(1);
    });

    testWidgets('permanently denied offers Open settings', (tester) async {
      bloc = blocIn(const HealthGateResolved(HealthAccess.permanentlyDenied()));
      await pumpScreen(tester, _page(bloc));

      expect(find.text('Health access is off'), findsOneWidget);
      await tester.ensureVisible(find.text('Open settings'));
      await tester.tap(find.text('Open settings'));

      verify(() => bloc.add(const HealthSettingsRequested())).called(1);
      verifyNever(() => bloc.add(const HealthAccessRequested()));
    });

    testWidgets('unavailable offers to install Health Connect', (tester) async {
      bloc = blocIn(const HealthGateResolved(HealthAccess.unavailable()));
      await pumpScreen(tester, _page(bloc));

      expect(find.text('Health Connect needed'), findsOneWidget);
      await tester.ensureVisible(find.text('Install Health Connect'));
      await tester.tap(find.text('Install Health Connect'));

      verify(() => bloc.add(const HealthInstallRequested())).called(1);
    });

    testWidgets('while the dialog is up the button waits', (tester) async {
      bloc = blocIn(
        const HealthGateResolved(HealthAccess.denied(), busy: true),
      );
      await pumpScreen(tester, _page(bloc), settle: false);
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the title is a heading', (tester) async {
      bloc = blocIn(const HealthGateResolved(HealthAccess.denied()));
      await pumpScreen(tester, _page(bloc));

      expect(
        tester.getSemantics(find.text('Allow health access')),
        matchesSemantics(
          label: 'Allow health access',
          isHeader: true,
          textDirection: TextDirection.ltr,
        ),
      );
    });
  });

  testWidgets('checking shows the tabs, with a spinner in Active', (
    tester,
  ) async {
    bloc = blocIn(const HealthGateChecking());
    await pumpScreen(tester, _page(bloc), settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Allow access'), findsNothing);
    expect(find.text('My Challenges'), findsOneWidget);
  });

  group('without health access', () {
    final items = [myChallenge(), myChallenge(id: 9, title: 'Mỹ Khê Bay')];

    testWidgets('both tabs open: the gate in Active, the list with the '
        'notice in My Challenges', (tester) async {
      getIt.unregister<MyChallengesBloc>();
      final mine = MockMyChallengesBloc();
      whenListen(
        mine,
        const Stream<MyChallengesState>.empty(),
        initialState: MyChallengesState(
          status: MyChallengesStatus.ready,
          items: items,
        ),
      );
      getIt.registerFactory<MyChallengesBloc>(() => mine);
      bloc = blocIn(const HealthGateResolved(HealthAccess.denied()));
      await pumpScreen(tester, _page(bloc, notice: HealthNotice.askable));

      expect(find.text('My Challenges'), findsOneWidget);
      expect(find.text('Allow health access'), findsOneWidget);
      expect(find.byType(HealthMetricList), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text(healthConsentNote), findsOneWidget);

      await tester.tap(find.text('My Challenges'));
      await tester.pumpAndSettle();

      final banner = find.textContaining("Steps aren't tracked yet");
      expect(banner, findsOneWidget);
      expect(find.text(items.first.challenge.title), findsOneWidget);
      expect(
        tester.getBottomLeft(banner).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.text(items.first.challenge.title)).dy,
        ),
      );
    });

    testWidgets('coming back from Settings with steps allowed shows the '
        'figures in the same tab', (tester) async {
      await getIt.reset();
      final repository = FakeHealthRepository(
        const HealthAccess.permanentlyDenied(),
      );
      registerHealthBlocs(repository);
      final gate = getIt<HealthGateBloc>()..add(const HealthGateStarted());
      addTearDown(gate.close);
      await pumpScreen(tester, _page(gate));
      expect(find.text('Health access is off'), findsOneWidget);
      expect(find.byType(ActivityTab), findsNothing);

      repository.access = _granted;
      _comeBack(tester);
      await tester.pumpAndSettle();

      expect(find.byType(ActivityTab), findsOneWidget);
      expect(find.byType(HealthGateView), findsNothing);
      expect(find.text('Refresh data'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('access turned on while on My Challenges keeps that tab', (
      tester,
    ) async {
      await getIt.reset();
      final repository = FakeHealthRepository(
        const HealthAccess.permanentlyDenied(),
      );
      registerHealthBlocs(repository);
      final gate = getIt<HealthGateBloc>()..add(const HealthGateStarted());
      addTearDown(gate.close);
      await pumpScreen(tester, _page(gate));
      await tester.tap(find.widgetWithText(Tab, 'My Challenges'));
      await tester.pumpAndSettle();

      repository.access = _granted;
      _comeBack(tester);
      await tester.pumpAndSettle();

      expect(
        DefaultTabController.of(tester.element(find.byType(TabBar))).index,
        1,
      );
      expect(find.byType(MyChallengesTab), findsOneWidget);
    });
  });

  group('the gate and the notice follow each other', () {
    testWidgets('access granted from the gate refreshes the notice', (
      tester,
    ) async {
      final gates = StreamController<HealthGateState>();
      addTearDown(gates.close);
      final gate = MockHealthGateBloc();
      whenListen(
        gate,
        gates.stream,
        initialState: const HealthGateResolved(HealthAccess.denied()),
      );
      final notice = MockHealthNoticeBloc();
      whenListen(
        notice,
        const Stream<HealthNoticeState>.empty(),
        initialState: const HealthNoticeState(notice: HealthNotice.askable),
      );
      await pumpScreen(
        tester,
        BlocProvider<HealthNoticeBloc>.value(
          value: notice,
          child: BlocProvider<HealthGateBloc>.value(
            value: gate,
            child: const ActiveChallengesPage(),
          ),
        ),
      );

      gates.add(const HealthGateResolved(HealthAccess.denied(), busy: true));
      await tester.pump();
      verifyNever(() => notice.add(const HealthNoticeRefreshed()));

      gates.add(const HealthGateResolved(_granted));
      await tester.pump();
      verify(() => notice.add(const HealthNoticeRefreshed())).called(1);
    });

    testWidgets('access asked from the notice rechecks the gate', (
      tester,
    ) async {
      final notices = StreamController<HealthNoticeState>();
      addTearDown(notices.close);
      final notice = MockHealthNoticeBloc();
      whenListen(
        notice,
        notices.stream,
        initialState: const HealthNoticeState(notice: HealthNotice.askable),
      );
      bloc = blocIn(const HealthGateResolved(HealthAccess.denied()));
      await pumpScreen(
        tester,
        BlocProvider<HealthNoticeBloc>.value(
          value: notice,
          child: BlocProvider<HealthGateBloc>.value(
            value: bloc,
            child: const ActiveChallengesPage(),
          ),
        ),
      );

      notices.add(
        const HealthNoticeState(notice: HealthNotice.askable, busy: true),
      );
      await tester.pump();
      verifyNever(() => bloc.add(const HealthGateRechecked()));

      notices.add(const HealthNoticeState());
      await tester.pump();
      verify(() => bloc.add(const HealthGateRechecked())).called(1);
    });
  });

  testWidgets('the list reloads when a sync finishes', (tester) async {
    final activity = MockActivityBloc();
    final mine = MockMyChallengesBloc();
    final states = StreamController<ActivityState>();
    addTearDown(states.close);
    whenListen(
      activity,
      states.stream,
      initialState: const ActivityState(
        allowed: {HealthMetric.steps},
        busy: true,
      ),
    );
    whenListen(
      mine,
      const Stream<MyChallengesState>.empty(),
      initialState: const MyChallengesState(status: MyChallengesStatus.ready),
    );
    getIt
      ..unregister<ActivityBloc>()
      ..unregister<MyChallengesBloc>()
      ..registerFactory<ActivityBloc>(() => activity)
      ..registerFactory<MyChallengesBloc>(() => mine);
    await pumpScreen(tester, _page(blocIn(const HealthGateResolved(_granted))));
    verifyNever(() => mine.add(const MyChallengesRefreshed()));

    states.add(const ActivityState(allowed: {HealthMetric.steps}));
    await tester.pump();

    verify(() => mine.add(const MyChallengesRefreshed())).called(1);
  });

  testWidgets('granted opens the tab, with no gate', (tester) async {
    bloc = blocIn(const HealthGateResolved(_granted));
    await pumpScreen(tester, _page(bloc));

    expect(find.text('My Challenges'), findsOneWidget);
    expect(find.text('Allow access'), findsNothing);
    expect(find.byType(HealthGateView), findsNothing);
  });

  group('rechecking', () {
    testWidgets('when the app comes back from Settings', (tester) async {
      bloc = blocIn(const HealthGateResolved(HealthAccess.permanentlyDenied()));
      await pumpScreen(tester, _page(bloc));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      verify(() => bloc.add(const HealthGateRechecked())).called(1);
    });

    testWidgets('each time the tab is opened again', (tester) async {
      bloc = blocIn(const HealthGateResolved(_granted));
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await pumpScreen(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: visible,
          // A tab behind the others has its tickers off, as in the shell.
          builder: (context, on, child) =>
              TickerMode(enabled: on, child: child!),
          child: _page(bloc),
        ),
      );
      verifyNever(() => bloc.add(const HealthGateRechecked()));

      visible.value = false;
      await tester.pump();
      verifyNever(() => bloc.add(const HealthGateRechecked()));

      visible.value = true;
      await tester.pump();
      verify(() => bloc.add(const HealthGateRechecked())).called(1);
    });
  });

  group('screen quality', () {
    for (final entry in _states.entries) {
      for (final size in [smallPhone, largePhone]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '${entry.key} fits and is accessible on $size at text x$textScale',
            (tester) async {
              final settle =
                  entry.value is! HealthGateChecking &&
                  !(entry.value is HealthGateResolved &&
                      (entry.value as HealthGateResolved).busy);
              await pumpScreen(
                tester,
                _page(blocIn(entry.value)),
                size: size,
                textScale: textScale,
                settle: settle,
              );
              if (!settle) await tester.pump();

              expectNoLayoutException(tester);
              await expectAccessible(tester);
            },
          );
        }
      }
    }
  });
}

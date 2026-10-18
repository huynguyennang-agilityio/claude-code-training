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
import 'package:stridequest/features/runs/presentation/pages/active_challenges_page.dart';
import 'package:stridequest/features/runs/presentation/widgets/health_gate_view.dart';

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

Widget _page(MockHealthGateBloc bloc) => BlocProvider<HealthGateBloc>.value(
  value: bloc,
  child: const ActiveChallengesPage(),
);

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

      await tester.tap(find.text('Allow access'));

      verify(() => bloc.add(const HealthAccessRequested())).called(1);
    });

    testWidgets('permanently denied offers Open settings', (tester) async {
      bloc = blocIn(const HealthGateResolved(HealthAccess.permanentlyDenied()));
      await pumpScreen(tester, _page(bloc));

      expect(find.text('Health access is off'), findsOneWidget);
      await tester.tap(find.text('Open settings'));

      verify(() => bloc.add(const HealthSettingsRequested())).called(1);
      verifyNever(() => bloc.add(const HealthAccessRequested()));
    });

    testWidgets('unavailable offers to install Health Connect', (tester) async {
      bloc = blocIn(const HealthGateResolved(HealthAccess.unavailable()));
      await pumpScreen(tester, _page(bloc));

      expect(find.text('Health Connect needed'), findsOneWidget);
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

  testWidgets('checking shows a spinner and no gate', (tester) async {
    bloc = blocIn(const HealthGateChecking());
    await pumpScreen(tester, _page(bloc), settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Allow access'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
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

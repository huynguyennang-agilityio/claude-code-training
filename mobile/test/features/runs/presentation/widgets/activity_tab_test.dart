import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/presentation/bloc/activity_bloc.dart';
import 'package:stridequest/features/runs/presentation/widgets/active_tabs.dart';

import '../../../../helpers/expect_accessible.dart';
import '../../../../helpers/pump_screen.dart';
import '../../../../helpers/runs_fixtures.dart';

const _all = {
  HealthMetric.steps,
  HealthMetric.calories,
  HealthMetric.distance,
  HealthMetric.sleep,
};

final _readAt = DateTime(2026, 10, 19, 21, 55);

ActivityReading _reading() => ActivityReading(
  readAt: _readAt,
  steps: 5490,
  calories: 312,
  distanceM: 3080,
  sleepMinutes: 390,
);

final _states = <String, ActivityState>{
  'loading': const ActivityState(allowed: _all, busy: true),
  'figures': ActivityState(
    allowed: _all,
    reading: _reading(),
    syncedAt: _readAt,
  ),
  'syncing': ActivityState(allowed: _all, reading: _reading(), busy: true),
  'refused metrics and a sync error': ActivityState(
    allowed: const {HealthMetric.steps, HealthMetric.distance},
    reading: ActivityReading(readAt: _readAt, steps: 5490, distanceM: 3080),
    error: 'Cannot reach StrideQuest. Check your connection.',
  ),
  'zeros': ActivityState(
    allowed: _all,
    reading: ActivityReading(
      readAt: _readAt,
      steps: 0,
      calories: 0,
      distanceM: 0,
      sleepMinutes: 0,
    ),
    syncedAt: _readAt,
  ),
};

Widget _tabs(MockActivityBloc bloc) =>
    BlocProvider<ActivityBloc>.value(value: bloc, child: const ActiveTabs());

MockActivityBloc _blocIn(ActivityState state) {
  final bloc = MockActivityBloc();
  whenListen(bloc, const Stream<ActivityState>.empty(), initialState: state);
  return bloc;
}

void main() {
  testWidgets('two tabs, Active first', (tester) async {
    await pumpScreen(tester, _tabs(_blocIn(_states['figures']!)));

    expect(find.widgetWithText(Tab, 'Active'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'My Challenges'), findsOneWidget);
    expect(find.text('Refresh data'), findsOneWidget);
  });

  testWidgets('the four tiles show the figures and when they were read', (
    tester,
  ) async {
    await pumpScreen(tester, _tabs(_blocIn(_states['figures']!)));

    expect(find.text('5,490'), findsOneWidget);
    expect(find.text('steps'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('kcal'), findsOneWidget);
    expect(find.text('3.08'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    expect(find.text('6.5'), findsOneWidget);
    expect(find.text('hrs'), findsOneWidget);
    expect(find.text('Today at 21:55'), findsNWidgets(4));
    expect(
      find.text(
        'Synced to StrideQuest at 21:55. Tap Refresh data to read your health '
        'data again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a tile reads as one sentence to a screen reader', (
    tester,
  ) async {
    await pumpScreen(tester, _tabs(_blocIn(_states['figures']!)));

    expect(
      find.bySemanticsLabel('Steps, 5,490 steps, today at 21:55'),
      findsOneWidget,
    );
  });

  testWidgets('a metric that is not allowed says so, and the note explains', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      _tabs(_blocIn(_states['refused metrics and a sync error']!)),
    );

    expect(find.text('Not allowed'), findsNWidgets(2));
    expect(
      find.text(
        'Calories and sleep time are not allowed, so they are not sent. Turn '
        'them on in Settings to see them here.',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Calories, not allowed'), findsOneWidget);
  });

  testWidgets('a failed sync shows a banner and keeps the figures', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      _tabs(_blocIn(_states['refused metrics and a sync error']!)),
    );

    expect(
      find.text('Cannot reach StrideQuest. Check your connection.'),
      findsOneWidget,
    );
    expect(find.text('5,490'), findsOneWidget);
  });

  testWidgets('zero figures are shown as zero', (tester) async {
    await pumpScreen(tester, _tabs(_blocIn(_states['zeros']!)));

    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('0.0'), findsOneWidget);
  });

  testWidgets('Refresh data asks for a refresh', (tester) async {
    final bloc = _blocIn(_states['figures']!);
    await pumpScreen(tester, _tabs(bloc));

    await tester.tap(find.text('Refresh data'));

    verify(() => bloc.add(const ActivityRefreshRequested())).called(1);
  });

  testWidgets('while syncing the button says so and waits', (tester) async {
    final bloc = _blocIn(_states['syncing']!);
    await pumpScreen(tester, _tabs(bloc));

    expect(find.text('Syncing…'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.bySubtype<FilledButton>());
    expect(button.onPressed, isNull);
  });

  testWidgets('the first read shows empty tiles and a note', (tester) async {
    await pumpScreen(tester, _tabs(_blocIn(_states['loading']!)));

    expect(find.text('—'), findsNWidgets(4));
    expect(
      find.text('Reading your health data and syncing it to StrideQuest.'),
      findsOneWidget,
    );
  });

  group('screen quality', () {
    for (final entry in _states.entries) {
      for (final size in [smallPhone, largePhone]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets(
            '${entry.key} fits and is accessible on $size at text x$textScale',
            (tester) async {
              await pumpScreen(
                tester,
                _tabs(_blocIn(entry.value)),
                size: size,
                textScale: textScale,
              );

              expectNoLayoutException(tester);
              await expectAccessible(tester);
            },
          );
        }
      }
    }
  });
}

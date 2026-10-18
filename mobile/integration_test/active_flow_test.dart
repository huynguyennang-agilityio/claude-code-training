import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stridequest/app.dart';
import 'package:stridequest/core/config/app_config.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:stridequest/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/repositories/health_repository.dart';

/// The Active tab in the real app against the real backend, with a fake health
/// source: the gate, Refresh data (which sends step records and the daily
/// figures), and the progress in My Challenges.
///
/// Needs the API running (see `sign_in_flow_test.dart`) and the demo challenges:
///
///     python -m demo.load_demo --email <an admin> --with-blocked
///
/// and a simulator or emulator:
///
///     flutter test integration_test/active_flow_test.dart -d <device id>
///
/// The test creates its own user and leaves the challenge before it ends, so it
/// can be run again and again.
///
/// The health data is fake on purpose: the real plugin needs real step records,
/// which a simulator cannot make (see `docs/health-real-device-checklist.md`).

const _oldQuarter = 'Old Quarter 50K Steps';
const _steps = 1250;

/// A health source that starts without access, grants it when asked, and reads
/// the same figures every time. Its step record starts now and ends a minute
/// ahead, which the backend counts: it is after the user joined and less than
/// five minutes ahead of the server's clock.
class _FakeHealth implements HealthRepository {
  var access = const HealthAccess.denied();
  var requests = 0;
  var stepRecordReads = 0;

  static const _allowed = {
    HealthMetric.steps,
    HealthMetric.calories,
    HealthMetric.distance,
    HealthMetric.sleep,
  };

  @override
  Future<HealthAccess> checkAccess() async => access;

  @override
  Future<HealthAccess> requestAccess() async {
    requests++;
    return access = const HealthAccess(
      HealthAccessStatus.granted,
      allowed: _allowed,
    );
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> installHealthConnect() async {}

  @override
  Future<ActivityReading> readToday(Set<HealthMetric> allowed) async =>
      ActivityReading(
        readAt: DateTime.now(),
        steps: 5490,
        calories: 312,
        distanceM: 3080,
        sleepMinutes: 390,
      );

  @override
  Future<List<DailyFigures>> readDays(
    Set<HealthMetric> allowed, {
    required int days,
  }) async {
    final now = DateTime.now();
    return [
      for (var back = days - 1; back >= 0; back--)
        DailyFigures(
          date: DateTime(now.year, now.month, now.day - back),
          steps: 5490,
          calories: 312,
          distanceM: 3080,
          sleepMinutes: 390,
        ),
    ];
  }

  /// One record, made on the first read and returned as it is every time, as a
  /// device would: syncing it again must not count it again.
  StepRecord? _record;

  @override
  Future<List<StepRecord>> readStepRecords({required DateTime from}) async {
    stepRecordReads++;
    final start = DateTime.now();
    return [
      _record ??= StepRecord(
        id: 'integration-${start.microsecondsSinceEpoch}',
        startTime: start,
        endTime: start.add(const Duration(minutes: 1)),
        steps: _steps,
      ),
    ];
  }
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for ${finder.describeMatch(Plurality.one)}.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, Finder finder, String text) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a user allows health access, refreshes and sees progress', (
    tester,
  ) async {
    final email = 'it-act-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'run4medals';
    await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)).post<void>(
      'auth/signup',
      data: {
        'email': email,
        'password': password,
        'display_name': 'Integration Walker',
      },
    );

    final health = _FakeHealth();
    await getIt.reset();
    configureDependencies();
    addTearDown(getIt.reset);
    // Everything is real except the health data.
    getIt
      ..unregister<HealthRepository>()
      ..registerLazySingleton<HealthRepository>(() => health);
    await getIt<AuthRepository>().signOut();
    final authBloc = getIt<AuthBloc>()..add(const AuthStarted());
    await tester.pumpWidget(StrideQuestApp(authBloc: authBloc));
    await tester.pumpAndSettle();

    await typeInto(tester, find.widgetWithText(AuthTextField, 'Email'), email);
    await typeInto(
      tester,
      find.widgetWithText(AuthTextField, 'Password'),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await pumpUntilFound(tester, find.text(_oldQuarter));

    // Join a run challenge that has started.
    await tester.tap(find.widgetWithText(FilledButton, 'Join').first);
    await pumpUntilFound(tester, find.text('Joined'));

    // The Active tab is behind the health gate until access is allowed.
    await tester.tap(_tab('Active'));
    await pumpUntilFound(tester, find.text('Allow health access'));
    expect(find.text('Refresh data'), findsNothing);
    await tester.tap(find.text('Allow access'));
    await pumpUntilFound(tester, find.text('Refresh data'));
    expect(health.requests, 1);

    // The first read syncs by itself: the figures show, and they were sent.
    await pumpUntilFound(
      tester,
      find.textContaining('Synced to StrideQuest at'),
    );
    expect(find.text('5,490'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('3.08'), findsOneWidget);
    expect(find.text('6.5'), findsOneWidget);
    expect(health.stepRecordReads, greaterThanOrEqualTo(1));
    expect(find.textContaining('Cannot reach'), findsNothing);

    // The backend counted the steps: the progress is in My Challenges.
    await tester.tap(find.widgetWithText(Tab, 'My Challenges'));
    await pumpUntilFound(tester, find.text(_oldQuarter));
    await pumpUntilFound(tester, find.text('Goal 2%'));
    expect(find.text('1,250 / 50,000 steps'), findsOneWidget);

    // Refresh data again: the same record is not counted twice.
    await tester.tap(find.widgetWithText(Tab, 'Active'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh data'));
    await tester.pump();
    await pumpUntilFound(
      tester,
      find.textContaining('Synced to StrideQuest at'),
    );
    await tester.tap(find.widgetWithText(Tab, 'My Challenges'));
    await pumpUntilFound(tester, find.text('Goal 2%'));

    // Open it from the list, and leave it so the next run starts clean.
    await tester.tap(find.text(_oldQuarter));
    await pumpUntilFound(tester, find.byTooltip('Back'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave challenge'));
    await pumpUntilFound(
      tester,
      find.widgetWithText(FilledButton, 'Join Challenge'),
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(_tab('Active'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'My Challenges'));
    await pumpUntilFound(tester, find.text('No challenge in progress'));
  });
}

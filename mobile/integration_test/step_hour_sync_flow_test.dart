import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/auth/domain/repositories/auth_repository.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:stridequest/features/runs/data/datasources/runs_remote_data_source.dart';
import 'package:stridequest/features/runs/data/datasources/sync_watermark_store.dart';
import 'package:stridequest/features/runs/data/models/runs_models.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/failures/runs_failure.dart';
import 'package:stridequest/features/runs/domain/repositories/health_repository.dart';
import 'package:stridequest/features/runs/domain/repositories/runs_repository.dart';
import 'package:stridequest/features/runs/domain/services/health_sync.dart';

/// The catch-up step-hour sync (`PUT runs/step-hours`, `PUT runs/daily-activity`)
/// against the real backend, with a fake health source that has every UTC hour
/// of the last 3 days. It drives the app's own path: `HealthSync.sync`, which
/// runs `SyncActivity`, the repository and the real remote data source.
///
/// The backend ignores an hour that starts before the user's latest sign in
/// (`session_started_at`), before the join or before `hours_from`. A fresh user
/// would therefore count none of the 3 missed days, so the test runs in two
/// phases with a database edit between them:
///
/// 1. `setup`: signs up a fresh user, joins "Hanoi Autumn 30K Steps" and keeps
///    the session in secure storage. It prints `#259 setup email=...`.
/// 2. Move that user's `session_started_at`, the enrollment's `joined_at` and
///    `hours_from` 4 days back in the database (by hand, not by this test).
/// 3. `sync`: starts from the stored session (it never signs in again, which
///    would move `session_started_at` to now), sets the sync watermark 3 days
///    back, syncs, then sets the watermark to the same point and syncs again
///    (a second app open), then checks a `422`. It prints `#259 ...` lines with
///    accepted, ignored and progress, leaves the challenge and signs out.
///
/// Run each phase on a device (`flutter test integration_test/` can't start on
/// a wireless iPhone):
///
///     flutter run -t integration_test/step_hour_sync_flow_test.dart -d <id> \
///       --dart-define=STEP_SYNC_PHASE=setup \
///       --dart-define=API_MODE=real \
///       --dart-define=API_BASE_URL=http://<mac-lan-ip>:8000/api/v1/
///
/// and again with `STEP_SYNC_PHASE=sync`. The base URL includes `/api/v1/`.
///
/// The health data is fake on purpose (see `active_flow_test.dart`).

const _phase = String.fromEnvironment('STEP_SYNC_PHASE');
const _challengeTitle = 'Hanoi Autumn 30K Steps';
const _stepsPerHour = 300;
const _password = 'run4medals';

void _log(String message) => debugPrint('#259 $message');

/// A health source with access to everything, whose step hours cover every UTC
/// hour of the last 3 days up to now, whatever window is asked for: the backend
/// is the one that must ignore what does not count.
class _FakeHealth implements HealthRepository {
  static const _allowed = {
    HealthMetric.steps,
    HealthMetric.calories,
    HealthMetric.distance,
    HealthMetric.sleep,
  };

  @override
  Future<HealthAccess> checkAccess() async =>
      const HealthAccess(HealthAccessStatus.granted, allowed: _allowed);

  @override
  Future<HealthAccess> requestAccess() => checkAccess();

  @override
  Future<List<StepHour>> readStepHours({
    required DateTime from,
    required DateTime to,
  }) async {
    final now = DateTime.now().toUtc();
    final thisHour = DateTime.utc(now.year, now.month, now.day, now.hour);
    return [
      for (var back = 3 * 24; back >= 0; back--)
        StepHour(
          hourStart: thisHour.subtract(Duration(hours: back)),
          steps: _stepsPerHour,
        ),
    ];
  }

  @override
  Future<bool> explainerDue() async => false;

  @override
  Future<void> recordExplainerShown() async {}

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

  @override
  Future<List<StepRecord>> readStepRecords({required DateTime from}) async =>
      const [];
}

/// The real data source, remembering what each step-hours call answered.
class _RecordingRunsSource implements RunsRemoteDataSource {
  _RecordingRunsSource(this.inner);

  final RunsRemoteDataSource inner;
  final stepHourResults = <StepSyncResultModel>[];
  final stepHourCounts = <int>[];

  @override
  Future<StepSyncResultModel> syncStepHours(
    List<Map<String, Object>> hours,
  ) async {
    final result = await inner.syncStepHours(hours);
    stepHourCounts.add(hours.length);
    stepHourResults.add(result);
    return result;
  }

  @override
  Future<StepSyncResultModel> syncSteps(List<Map<String, Object>> samples) =>
      inner.syncSteps(samples);

  @override
  Future<void> saveDailyActivity(List<Map<String, Object>> days) =>
      inner.saveDailyActivity(days);

  @override
  Future<MyChallengePageModel> myChallenges({String? cursor, int limit = 20}) =>
      inner.myChallenges(cursor: cursor, limit: limit);
}

Future<ChallengeSummary> _findChallenge(ChallengeRepository challenges) async {
  String? cursor;
  do {
    final page = await challenges.list(cursor: cursor, limit: 50);
    for (final item in page.items) {
      if (item.title == _challengeTitle) return item;
    }
    cursor = page.nextCursor;
  } while (cursor != null);
  fail('Challenge "$_challengeTitle" not found: load the demo challenges.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingRunsSource runs;

  Future<void> boot() async {
    await getIt.reset();
    configureDependencies();
    addTearDown(getIt.reset);
    // Everything is real except the health data and a recorder on the runs
    // data source.
    final real = getIt<RunsRemoteDataSource>();
    runs = _RecordingRunsSource(real);
    getIt
      ..unregister<HealthRepository>()
      ..registerLazySingleton<HealthRepository>(_FakeHealth.new)
      ..unregister<RunsRemoteDataSource>()
      ..registerLazySingleton<RunsRemoteDataSource>(() => runs);
  }

  testWidgets('setup: a fresh user joins a step challenge', (tester) async {
    if (_phase != 'setup') {
      markTestSkipped('Run with STEP_SYNC_PHASE=setup.');
      return;
    }
    await boot();
    final email =
        'it-sync-${DateTime.now().millisecondsSinceEpoch}@example.com';
    await getIt<AuthRepository>().signOut();
    final user = await getIt<AuthRepository>().signUp(
      email: email,
      password: _password,
      displayName: 'Integration Sync',
    );
    final challenge = await _findChallenge(getIt<ChallengeRepository>());
    await getIt<ChallengeRepository>().join(challenge.id);
    // The session stays in secure storage for the sync phase.
    _log('setup email=$email user_id=${user.id} challenge_id=${challenge.id}');
  });

  testWidgets('sync: the missed days are sent, and sending them again adds '
      'nothing', (tester) async {
    if (_phase != 'sync') {
      markTestSkipped('Run with STEP_SYNC_PHASE=sync.');
      return;
    }
    await boot();
    final user = await getIt<AuthRepository>().restoreSession();
    expect(user, isNotNull, reason: 'Run the setup phase first.');
    final challenge = await _findChallenge(getIt<ChallengeRepository>());
    final store = getIt<SyncWatermarkStore>();
    final sync = getIt<HealthSync>();
    final repository = getIt<RunsRepository>();

    Future<int> progress() async {
      final page = await repository.myChallenges(limit: 50);
      return page.items
          .firstWhere((item) => item.challenge.id == challenge.id)
          .progress
          .currentValue;
    }

    // Behave like an app that was last open 3 days ago.
    final lastOpen = DateTime.now().subtract(const Duration(days: 3));
    Future<void> reopen() async {
      await store.saveFirstSyncAt(user!.id, lastOpen);
      await store.saveWatermark(user.id, lastOpen);
      await sync.sync(force: true);
      expect(sync.state.error, isNull);
    }

    try {
      final before = await progress();
      await reopen();
      final first = runs.stepHourResults.single;
      final afterFirst = await progress();
      _log(
        'sync 1: hours_sent=${runs.stepHourCounts.last} '
        'accepted=${first.accepted} ignored=${first.ignored} '
        'progress $before -> $afterFirst',
      );
      expect(first.accepted + first.ignored, runs.stepHourCounts.last);
      if (first.accepted > 0) expect(afterFirst, greaterThan(before));

      await reopen();
      final second = runs.stepHourResults.last;
      final afterSecond = await progress();
      _log(
        'sync 2: hours_sent=${runs.stepHourCounts.last} '
        'accepted=${second.accepted} ignored=${second.ignored} '
        'progress $afterFirst -> $afterSecond',
      );
      expect(runs.stepHourResults, hasLength(2));
      expect(afterSecond, afterFirst, reason: 'the same hours count once');

      // A negative step count breaks a field rule.
      final real =
          (getIt<RunsRemoteDataSource>() as _RecordingRunsSource).inner;
      await expectLater(
        real.syncStepHours([
          {'hour_start': '2026-11-02T06:00:00Z', 'steps': -1},
        ]),
        throwsA(const RunsFailure(RunsFailureCode.validation)),
      );
      await expectLater(
        real.syncStepHours([]),
        throwsA(const RunsFailure(RunsFailureCode.validation)),
      );
      _log('422 validation_error for a negative steps value and an empty list');
    } finally {
      await getIt<ChallengeRepository>().leave(challenge.id);
      await getIt<AuthRepository>().signOut();
    }
  });
}

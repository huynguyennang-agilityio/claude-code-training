import 'package:bloc_test/bloc_test.dart';
import 'package:stridequest/core/di/injection.dart';
import 'package:stridequest/features/runs/data/datasources/health_data_source.dart';
import 'package:stridequest/features/runs/data/datasources/health_prompt_store.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/entities/health_access.dart';
import 'package:stridequest/features/runs/domain/repositories/health_repository.dart';
import 'package:stridequest/features/runs/domain/usecases/sync_activity.dart';
import 'package:stridequest/features/runs/presentation/bloc/activity_bloc.dart';
import 'package:stridequest/features/runs/presentation/bloc/health_gate_bloc.dart';
import 'package:stridequest/features/runs/presentation/bloc/my_challenges_bloc.dart';

import 'runs_fixtures.dart';

class MockHealthGateBloc extends MockBloc<HealthGateEvent, HealthGateState>
    implements HealthGateBloc {}

/// A [HealthRepository] that answers with [access] and counts what was asked.
class FakeHealthRepository implements HealthRepository {
  FakeHealthRepository([this.access = _granted]);

  static const _granted = HealthAccess(
    HealthAccessStatus.granted,
    allowed: {HealthMetric.steps},
  );

  HealthAccess access;
  HealthAccess? afterRequest;
  var checks = 0;
  var requests = 0;
  var settingsOpened = 0;
  var installs = 0;
  bool due = true;
  var explainerShown = 0;
  Object? readDaysError;
  var readDaysCalls = 0;
  ({Set<HealthMetric> allowed, int days})? lastReadDays;

  ActivityReading reading = ActivityReading(
    readAt: DateTime(2026, 10, 19, 21, 55),
  );
  List<DailyFigures> days = const [];
  List<StepRecord> records = const [];
  Object? readError;
  List<StepHour> hours = const [];
  var readTodayCalls = 0;
  DateTime? stepsFrom;
  ({DateTime from, DateTime to})? hoursRead;

  @override
  Future<ActivityReading> readToday(Set<HealthMetric> allowed) async {
    readTodayCalls++;
    if (readError != null) throw readError!;
    return reading;
  }

  @override
  Future<List<DailyFigures>> readDays(
    Set<HealthMetric> allowed, {
    required int days,
  }) async {
    readDaysCalls++;
    lastReadDays = (allowed: allowed, days: days);
    if (readDaysError != null) throw readDaysError!;
    return this.days;
  }

  @override
  Future<List<StepHour>> readStepHours({
    required DateTime from,
    required DateTime to,
  }) async {
    hoursRead = (from: from, to: to);
    if (readError != null) throw readError!;
    return hours;
  }

  @override
  Future<bool> explainerDue() async => due;

  @override
  Future<void> recordExplainerShown() async => explainerShown++;

  @override
  Future<List<StepRecord>> readStepRecords({required DateTime from}) async {
    stepsFrom = from;
    return records;
  }

  @override
  Future<HealthAccess> checkAccess() async {
    checks++;
    return access;
  }

  @override
  Future<HealthAccess> requestAccess() async {
    requests++;
    return access = afterRequest ?? access;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<void> installHealthConnect() async => installs++;
}

/// A [HealthDataSource] whose answers a test sets.
class FakeHealthDataSource implements HealthDataSource {
  bool available = true;

  /// What the platform says is allowed; null is "will not say" (iOS).
  Set<HealthMetric>? allowed;

  /// What the system dialog does: the metrics it allows, when shown.
  Set<HealthMetric> grantsOnRequest = {};
  bool dialogShown = true;
  final totals = <HealthMetric, int>{};
  final totalCalls = <(HealthMetric, DateTime, DateTime)>[];
  List<StepRecord> records = const [];
  List<StepHour> hours = const [];
  final hourCalls = <(DateTime, DateTime)>[];
  final stepTotalCalls = <(DateTime, DateTime)>[];
  DateTime? recordsFrom;
  DateTime? recordsTo;
  Object? readError;
  var requests = 0;
  var settingsOpened = 0;
  var installs = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Set<HealthMetric>?> allowedMetrics() async => allowed;

  @override
  Future<bool> requestAuthorization() async {
    requests++;
    if (dialogShown && allowed != null) {
      allowed = {...allowed!, ...grantsOnRequest};
    }
    return dialogShown;
  }

  @override
  Future<void> installHealthConnect() async => installs++;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<int> total(HealthMetric metric, DateTime from, DateTime to) async {
    if (readError != null) throw readError!;
    totalCalls.add((metric, from, to));
    return totals[metric] ?? 0;
  }

  @override
  Future<List<StepHour>> stepHours(DateTime from, DateTime to) async {
    if (readError != null) throw readError!;
    hourCalls.add((from, to));
    return hours;
  }

  @override
  Future<int> stepTotal(DateTime from, DateTime to) async {
    if (readError != null) throw readError!;
    stepTotalCalls.add((from, to));
    return hours.fold<int>(0, (sum, hour) => sum + hour.steps);
  }

  @override
  Future<List<StepRecord>> stepRecords(DateTime from, DateTime to) async {
    if (readError != null) throw readError!;
    recordsFrom = from;
    recordsTo = to;
    return records;
  }
}

class InMemoryHealthPromptStore implements HealthPromptStore {
  InMemoryHealthPromptStore([this.count = 0]);

  int count;
  DateTime? shownAt;

  @override
  Future<int> askedCount() async => count;

  @override
  Future<void> recordAsked() async => count++;

  @override
  Future<DateTime?> explainerShownAt() async => shownAt;

  @override
  Future<void> recordExplainerShown(DateTime at) async => shownAt = at;
}

/// Registers the blocs the Active route asks `getIt` for, built on [repository]
/// (and an in-memory backend for the sync).
void registerHealthBlocs([HealthRepository? repository]) {
  final repo = repository ?? FakeHealthRepository();
  final runs = FakeRunsRepository();
  getIt
    ..registerFactory<HealthGateBloc>(() => HealthGateBloc(repo))
    ..registerFactory<ActivityBloc>(
      () => ActivityBloc(SyncActivity(repo, runs, FakeSyncStateRepository())),
    )
    ..registerFactory<MyChallengesBloc>(() => MyChallengesBloc(runs));
}

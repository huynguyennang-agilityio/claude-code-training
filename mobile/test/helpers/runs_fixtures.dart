import 'package:bloc_test/bloc_test.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/repositories/runs_repository.dart';
import 'package:stridequest/features/runs/domain/repositories/sync_state_repository.dart';
import 'package:stridequest/features/runs/presentation/bloc/activity_bloc.dart';
import 'package:stridequest/features/runs/presentation/bloc/my_challenges_bloc.dart';

class MockActivityBloc extends MockBloc<ActivityEvent, ActivityState>
    implements ActivityBloc {}

class MockMyChallengesBloc
    extends MockBloc<MyChallengesEvent, MyChallengesState>
    implements MyChallengesBloc {}

/// A [RunsRepository] that answers from memory and records what it was sent.
class FakeRunsRepository implements RunsRepository {
  DateTime? earliest;
  DateTime? counting;
  Object? error;
  final syncedRecords = <List<StepRecord>>[];
  final savedDays = <List<DailyFigures>>[];
  final syncedHours = <List<StepHour>>[];

  /// The 1-based number of the `saveDailyActivity` call that fails with
  /// [error], or null when [error] fails every call.
  int? failDaysCall;
  var daysCalls = 0;
  var earliestCalls = 0;
  var countingCalls = 0;
  MyChallengePage page = const MyChallengePage(items: []);

  @override
  Future<StepSyncResult> syncSteps(List<StepRecord> records) async {
    if (error != null) throw error!;
    syncedRecords.add(records);
    return StepSyncResult(accepted: records.length, ignored: 0);
  }

  @override
  Future<StepSyncResult> syncStepHours(List<StepHour> hours) async {
    if (error != null && failDaysCall == null) throw error!;
    syncedHours.add(hours);
    return StepSyncResult(accepted: hours.length, ignored: 0);
  }

  @override
  Future<void> saveDailyActivity(List<DailyFigures> days) async {
    daysCalls++;
    if (error != null && (failDaysCall == null || failDaysCall == daysCalls)) {
      throw error!;
    }
    savedDays.add(days);
  }

  @override
  Future<MyChallengePage> myChallenges({String? cursor, int limit = 20}) async {
    if (error != null) throw error!;
    return page;
  }

  @override
  Future<DateTime?> earliestRunJoin() async {
    earliestCalls++;
    if (error != null && failDaysCall == null) throw error!;
    return earliest;
  }

  @override
  Future<DateTime?> earliestRunCounting() async {
    countingCalls++;
    if (error != null) throw error!;
    return counting;
  }
}

/// A [SyncStateRepository] that keeps its times in memory.
class FakeSyncStateRepository implements SyncStateRepository {
  DateTime? stored;
  DateTime? first;
  var loads = 0;

  /// The `now` of the latest [load].
  DateTime? loadedAt;

  @override
  Future<SyncState> load(DateTime now) async {
    loads++;
    loadedAt = now;
    return _FakeSyncState(this, stored, first ??= now);
  }
}

class _FakeSyncState implements SyncState {
  _FakeSyncState(this._repository, this.watermark, this.firstSyncAt);

  final FakeSyncStateRepository _repository;

  @override
  final DateTime? watermark;

  @override
  final DateTime firstSyncAt;

  @override
  Future<void> saveWatermark(DateTime at) async => _repository.stored = at;
}

/// A challenge the caller is in, with progress. By default a run challenge that
/// started on Oct 1 and is 18% done.
MyChallenge myChallenge({
  int id = 7,
  String title = 'Old Quarter 50K Steps',
  ChallengeType type = ChallengeType.run,
  EnrollmentStatus status = EnrollmentStatus.active,
  DateTime? startsAt,
  int current = 9000,
  int target = 50000,
  int percent = 18,
  bool started = true,
  String? city = 'Hà Nội',
}) => MyChallenge(
  challenge: ChallengeSummary(
    id: id,
    title: title,
    type: type,
    target: target,
    startsAt: startsAt ?? DateTime.utc(2026, 10, 1),
    endsAt: DateTime.utc(2026, 10, 31),
    participantCount: 12,
    city: city,
    enrollment: Enrollment(status: status, joinedAt: DateTime.utc(2026, 10, 5)),
  ),
  progress: Progress(
    currentValue: type == ChallengeType.run ? current : 0,
    targetValue: target,
    percent: type == ChallengeType.run ? percent : 0,
    tracked: type == ChallengeType.run,
    started: started,
  ),
);

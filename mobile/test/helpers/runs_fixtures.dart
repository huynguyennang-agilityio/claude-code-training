import 'package:bloc_test/bloc_test.dart';
import 'package:stridequest/features/challenges/domain/entities/challenge.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/repositories/runs_repository.dart';
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
  Object? error;
  final syncedRecords = <List<StepRecord>>[];
  final savedDays = <List<DailyFigures>>[];
  var earliestCalls = 0;
  MyChallengePage page = const MyChallengePage(items: []);

  @override
  Future<StepSyncResult> syncSteps(List<StepRecord> records) async {
    if (error != null) throw error!;
    syncedRecords.add(records);
    return StepSyncResult(accepted: records.length, ignored: 0);
  }

  @override
  Future<void> saveDailyActivity(List<DailyFigures> days) async {
    if (error != null) throw error!;
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
    if (error != null) throw error!;
    return earliest;
  }
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

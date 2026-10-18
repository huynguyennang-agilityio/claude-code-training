import 'package:bloc_test/bloc_test.dart';
import 'package:stridequest/features/runs/domain/entities/activity.dart';
import 'package:stridequest/features/runs/domain/repositories/runs_repository.dart';
import 'package:stridequest/features/runs/presentation/bloc/activity_bloc.dart';

class MockActivityBloc extends MockBloc<ActivityEvent, ActivityState>
    implements ActivityBloc {}

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

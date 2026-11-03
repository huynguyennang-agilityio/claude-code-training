import '../models/runs_models.dart';
import 'runs_fixtures.dart';
import 'runs_remote_data_source.dart';

/// In-memory [RunsRemoteDataSource] for tests and for debug builds run with
/// `--dart-define=API_MODE=mock` (registered in `MockApiModule`). It answers
/// with the examples of `docs/api/examples/runs/` and keeps nothing.
class FakeRunsRemoteDataSource implements RunsRemoteDataSource {
  const FakeRunsRemoteDataSource({this.latency = Duration.zero});

  /// Delay added to every call, so loading states can be seen in the UI.
  final Duration latency;

  @override
  Future<StepSyncResultModel> syncSteps(
    List<Map<String, Object>> samples,
  ) async {
    await Future<void>.delayed(latency);
    return StepSyncResultModel.fromJson(stepSyncResultFixture);
  }

  @override
  Future<StepSyncResultModel> syncStepHours(
    List<Map<String, Object>> hours,
  ) async {
    await Future<void>.delayed(latency);
    return StepSyncResultModel.fromJson(stepHoursResultFixture);
  }

  @override
  Future<void> saveDailyActivity(List<Map<String, Object>> days) =>
      Future<void>.delayed(latency);

  @override
  Future<MyChallengePageModel> myChallenges({
    String? cursor,
    int limit = 20,
  }) async {
    await Future<void>.delayed(latency);
    return MyChallengePageModel.fromJson(myChallengePageFixture);
  }
}

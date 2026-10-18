import 'package:injectable/injectable.dart';

import '../../../challenges/domain/entities/challenge.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/runs_repository.dart';
import '../datasources/runs_remote_data_source.dart';
import '../models/runs_models.dart';

@LazySingleton(as: RunsRepository)
class RunsRepositoryImpl implements RunsRepository {
  RunsRepositoryImpl(this._remote);

  /// The most samples one request carries (`docs/api/runs.md`).
  static const maxSamplesPerRequest = 500;

  /// The most days one request carries.
  static const maxDaysPerRequest = 7;

  /// The most a page of the caller's challenges holds.
  static const _pageSize = 50;

  final RunsRemoteDataSource _remote;

  @override
  Future<StepSyncResult> syncSteps(List<StepRecord> records) async {
    var accepted = 0;
    var ignored = 0;
    for (var start = 0; start < records.length; start += maxSamplesPerRequest) {
      final end = start + maxSamplesPerRequest;
      final chunk = records.sublist(
        start,
        end > records.length ? records.length : end,
      );
      final result = await _remote.syncSteps([
        for (final record in chunk) stepRecordJson(record),
      ]);
      accepted += result.accepted;
      ignored += result.ignored;
    }
    return StepSyncResult(accepted: accepted, ignored: ignored);
  }

  @override
  Future<void> saveDailyActivity(List<DailyFigures> days) async {
    for (var start = 0; start < days.length; start += maxDaysPerRequest) {
      final end = start + maxDaysPerRequest;
      await _remote.saveDailyActivity([
        for (final day in days.sublist(
          start,
          end > days.length ? days.length : end,
        ))
          dailyFiguresJson(day),
      ]);
    }
  }

  @override
  Future<MyChallengePage> myChallenges({
    String? cursor,
    int limit = 20,
  }) async =>
      (await _remote.myChallenges(cursor: cursor, limit: limit)).toEntity();

  @override
  Future<DateTime?> earliestRunJoin() async {
    DateTime? earliest;
    String? cursor;
    do {
      final page = await _remote.myChallenges(cursor: cursor, limit: _pageSize);
      for (final item in page.items) {
        final challenge = item.challenge.toEntity();
        final enrollment = challenge.enrollment;
        if (challenge.type != ChallengeType.run ||
            enrollment?.status != EnrollmentStatus.active) {
          continue;
        }
        final joined = enrollment!.joinedAt;
        if (earliest == null || joined.isBefore(earliest)) earliest = joined;
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return earliest;
  }
}

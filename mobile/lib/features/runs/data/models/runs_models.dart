import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../challenges/data/models/challenge_models.dart';
import '../../domain/entities/activity.dart';

part 'runs_models.freezed.dart';
part 'runs_models.g.dart';

/// The API shapes of `docs/api/runs.md`.
@freezed
abstract class ProgressModel with _$ProgressModel {
  const factory ProgressModel({
    required int currentValue,
    required int targetValue,
    required int percent,
    required bool tracked,
    required bool started,
  }) = _ProgressModel;

  const ProgressModel._();

  factory ProgressModel.fromJson(Map<String, dynamic> json) =>
      _$ProgressModelFromJson(json);

  Progress toEntity() => Progress(
    currentValue: currentValue,
    targetValue: targetValue,
    percent: percent,
    tracked: tracked,
    started: started,
  );
}

@freezed
abstract class MyChallengeModel with _$MyChallengeModel {
  const factory MyChallengeModel({
    required ChallengeSummaryModel challenge,
    required ProgressModel progress,
  }) = _MyChallengeModel;

  const MyChallengeModel._();

  factory MyChallengeModel.fromJson(Map<String, dynamic> json) =>
      _$MyChallengeModelFromJson(json);

  MyChallenge toEntity() => MyChallenge(
    challenge: challenge.toEntity(),
    progress: progress.toEntity(),
  );
}

@freezed
abstract class MyChallengePageModel with _$MyChallengePageModel {
  const factory MyChallengePageModel({
    required List<MyChallengeModel> items,
    String? nextCursor,
  }) = _MyChallengePageModel;

  const MyChallengePageModel._();

  factory MyChallengePageModel.fromJson(Map<String, dynamic> json) =>
      _$MyChallengePageModelFromJson(json);

  MyChallengePage toEntity() => MyChallengePage(
    items: [for (final item in items) item.toEntity()],
    nextCursor: nextCursor,
  );
}

@freezed
abstract class StepSyncResultModel with _$StepSyncResultModel {
  const factory StepSyncResultModel({
    required int accepted,
    required int ignored,
  }) = _StepSyncResultModel;

  const StepSyncResultModel._();

  factory StepSyncResultModel.fromJson(Map<String, dynamic> json) =>
      _$StepSyncResultModelFromJson(json);

  StepSyncResult toEntity() =>
      StepSyncResult(accepted: accepted, ignored: ignored);
}

/// The JSON a request carries.
Map<String, Object> stepRecordJson(StepRecord record) => {
  'health_record_id': record.id,
  'start_time': record.startTime.toUtc().toIso8601String(),
  'end_time': record.endTime.toUtc().toIso8601String(),
  'steps': record.steps,
};

Map<String, Object> dailyFiguresJson(DailyFigures day) => {
  'date': _dateText(day.date),
  'steps': ?day.steps,
  'calories_kcal': ?day.calories,
  'distance_m': ?day.distanceM,
  'sleep_minutes': ?day.sleepMinutes,
};

String _dateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

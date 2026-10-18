// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'runs_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProgressModel _$ProgressModelFromJson(Map<String, dynamic> json) =>
    _ProgressModel(
      currentValue: (json['current_value'] as num).toInt(),
      targetValue: (json['target_value'] as num).toInt(),
      percent: (json['percent'] as num).toInt(),
      tracked: json['tracked'] as bool,
      started: json['started'] as bool,
    );

Map<String, dynamic> _$ProgressModelToJson(_ProgressModel instance) =>
    <String, dynamic>{
      'current_value': instance.currentValue,
      'target_value': instance.targetValue,
      'percent': instance.percent,
      'tracked': instance.tracked,
      'started': instance.started,
    };

_MyChallengeModel _$MyChallengeModelFromJson(Map<String, dynamic> json) =>
    _MyChallengeModel(
      challenge: ChallengeSummaryModel.fromJson(
        json['challenge'] as Map<String, dynamic>,
      ),
      progress: ProgressModel.fromJson(
        json['progress'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$MyChallengeModelToJson(_MyChallengeModel instance) =>
    <String, dynamic>{
      'challenge': instance.challenge.toJson(),
      'progress': instance.progress.toJson(),
    };

_MyChallengePageModel _$MyChallengePageModelFromJson(
  Map<String, dynamic> json,
) => _MyChallengePageModel(
  items: (json['items'] as List<dynamic>)
      .map((e) => MyChallengeModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextCursor: json['next_cursor'] as String?,
);

Map<String, dynamic> _$MyChallengePageModelToJson(
  _MyChallengePageModel instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'next_cursor': instance.nextCursor,
};

_StepSyncResultModel _$StepSyncResultModelFromJson(Map<String, dynamic> json) =>
    _StepSyncResultModel(
      accepted: (json['accepted'] as num).toInt(),
      ignored: (json['ignored'] as num).toInt(),
    );

Map<String, dynamic> _$StepSyncResultModelToJson(
  _StepSyncResultModel instance,
) => <String, dynamic>{
  'accepted': instance.accepted,
  'ignored': instance.ignored,
};

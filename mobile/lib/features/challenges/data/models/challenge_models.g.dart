// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EnrollmentModel _$EnrollmentModelFromJson(Map<String, dynamic> json) =>
    _EnrollmentModel(
      status: json['status'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );

Map<String, dynamic> _$EnrollmentModelToJson(_EnrollmentModel instance) =>
    <String, dynamic>{
      'status': instance.status,
      'joined_at': instance.joinedAt.toIso8601String(),
    };

_MedalModel _$MedalModelFromJson(Map<String, dynamic> json) => _MedalModel(
  tier: json['tier'] as String,
  name: json['name'] as String,
  thresholdValue: (json['threshold_value'] as num).toInt(),
  imageUrl: json['image_url'] as String,
);

Map<String, dynamic> _$MedalModelToJson(_MedalModel instance) =>
    <String, dynamic>{
      'tier': instance.tier,
      'name': instance.name,
      'threshold_value': instance.thresholdValue,
      'image_url': instance.imageUrl,
    };

_BlockedByModel _$BlockedByModelFromJson(Map<String, dynamic> json) =>
    _BlockedByModel(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
    );

Map<String, dynamic> _$BlockedByModelToJson(_BlockedByModel instance) =>
    <String, dynamic>{'id': instance.id, 'title': instance.title};

_ChallengeSummaryModel _$ChallengeSummaryModelFromJson(
  Map<String, dynamic> json,
) => _ChallengeSummaryModel(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  type: json['type'] as String,
  targetValue: (json['target_value'] as num).toInt(),
  startsAt: DateTime.parse(json['starts_at'] as String),
  endsAt: DateTime.parse(json['ends_at'] as String),
  participantCount: (json['participant_count'] as num).toInt(),
  coverImageUrl: json['cover_image_url'] as String?,
  city: json['city'] as String?,
  landmark: json['landmark'] as String?,
  enrollment: json['enrollment'] == null
      ? null
      : EnrollmentModel.fromJson(json['enrollment'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ChallengeSummaryModelToJson(
  _ChallengeSummaryModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'type': instance.type,
  'target_value': instance.targetValue,
  'starts_at': instance.startsAt.toIso8601String(),
  'ends_at': instance.endsAt.toIso8601String(),
  'participant_count': instance.participantCount,
  'cover_image_url': instance.coverImageUrl,
  'city': instance.city,
  'landmark': instance.landmark,
  'enrollment': instance.enrollment?.toJson(),
};

_ChallengePageModel _$ChallengePageModelFromJson(Map<String, dynamic> json) =>
    _ChallengePageModel(
      items: (json['items'] as List<dynamic>)
          .map((e) => ChallengeSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );

Map<String, dynamic> _$ChallengePageModelToJson(_ChallengePageModel instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'next_cursor': instance.nextCursor,
    };

_ChallengeModel _$ChallengeModelFromJson(Map<String, dynamic> json) =>
    _ChallengeModel(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      type: json['type'] as String,
      targetValue: (json['target_value'] as num).toInt(),
      descriptionMd: json['description_md'] as String,
      termsMd: json['terms_md'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      medals: (json['medals'] as List<dynamic>)
          .map((e) => MedalModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      participantCount: (json['participant_count'] as num).toInt(),
      coverImageUrl: json['cover_image_url'] as String?,
      city: json['city'] as String?,
      landmark: json['landmark'] as String?,
      enrollment: json['enrollment'] == null
          ? null
          : EnrollmentModel.fromJson(
              json['enrollment'] as Map<String, dynamic>,
            ),
      blockedBy: json['blocked_by'] == null
          ? null
          : BlockedByModel.fromJson(json['blocked_by'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ChallengeModelToJson(_ChallengeModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'type': instance.type,
      'target_value': instance.targetValue,
      'description_md': instance.descriptionMd,
      'terms_md': instance.termsMd,
      'starts_at': instance.startsAt.toIso8601String(),
      'ends_at': instance.endsAt.toIso8601String(),
      'medals': instance.medals.map((e) => e.toJson()).toList(),
      'participant_count': instance.participantCount,
      'cover_image_url': instance.coverImageUrl,
      'city': instance.city,
      'landmark': instance.landmark,
      'enrollment': instance.enrollment?.toJson(),
      'blocked_by': instance.blockedBy?.toJson(),
    };

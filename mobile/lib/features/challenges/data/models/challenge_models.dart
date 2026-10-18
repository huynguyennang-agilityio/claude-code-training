import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/challenge.dart';

part 'challenge_models.freezed.dart';
part 'challenge_models.g.dart';

/// The API shapes of `docs/api/challenges.md`.
@freezed
abstract class EnrollmentModel with _$EnrollmentModel {
  const factory EnrollmentModel({
    required String status,
    required DateTime joinedAt,
  }) = _EnrollmentModel;

  const EnrollmentModel._();

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentModelFromJson(json);

  Enrollment toEntity() =>
      Enrollment(status: EnrollmentStatus.fromWire(status), joinedAt: joinedAt);
}

@freezed
abstract class MedalModel with _$MedalModel {
  const factory MedalModel({
    required String tier,
    required String name,
    required int thresholdValue,
    required String imageUrl,
  }) = _MedalModel;

  const MedalModel._();

  factory MedalModel.fromJson(Map<String, dynamic> json) =>
      _$MedalModelFromJson(json);

  Medal toEntity() => Medal(
    tier: MedalTier.fromWire(tier),
    name: name,
    threshold: thresholdValue,
    imageUrl: imageUrl,
  );
}

@freezed
abstract class BlockedByModel with _$BlockedByModel {
  const factory BlockedByModel({required int id, required String title}) =
      _BlockedByModel;

  const BlockedByModel._();

  factory BlockedByModel.fromJson(Map<String, dynamic> json) =>
      _$BlockedByModelFromJson(json);

  BlockingChallenge toEntity() => BlockingChallenge(id: id, title: title);
}

@freezed
abstract class ChallengeSummaryModel with _$ChallengeSummaryModel {
  const factory ChallengeSummaryModel({
    required int id,
    required String title,
    required String type,
    required int targetValue,
    required DateTime startsAt,
    required DateTime endsAt,
    required int participantCount,
    String? coverImageUrl,
    String? city,
    String? landmark,
    EnrollmentModel? enrollment,
  }) = _ChallengeSummaryModel;

  const ChallengeSummaryModel._();

  factory ChallengeSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$ChallengeSummaryModelFromJson(json);

  ChallengeSummary toEntity() => ChallengeSummary(
    id: id,
    title: title,
    type: ChallengeType.fromWire(type),
    target: targetValue,
    startsAt: startsAt,
    endsAt: endsAt,
    participantCount: participantCount,
    coverImageUrl: coverImageUrl,
    city: city,
    landmark: landmark,
    enrollment: enrollment?.toEntity(),
  );
}

@freezed
abstract class ChallengePageModel with _$ChallengePageModel {
  const factory ChallengePageModel({
    required List<ChallengeSummaryModel> items,
    String? nextCursor,
  }) = _ChallengePageModel;

  const ChallengePageModel._();

  factory ChallengePageModel.fromJson(Map<String, dynamic> json) =>
      _$ChallengePageModelFromJson(json);

  ChallengePage toEntity() => ChallengePage(
    items: [for (final item in items) item.toEntity()],
    nextCursor: nextCursor,
  );
}

@freezed
abstract class ChallengeModel with _$ChallengeModel {
  const factory ChallengeModel({
    required int id,
    required String title,
    required String type,
    required int targetValue,
    required String descriptionMd,
    required String termsMd,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<MedalModel> medals,
    required int participantCount,
    String? coverImageUrl,
    String? city,
    String? landmark,
    EnrollmentModel? enrollment,
    BlockedByModel? blockedBy,
  }) = _ChallengeModel;

  const ChallengeModel._();

  factory ChallengeModel.fromJson(Map<String, dynamic> json) =>
      _$ChallengeModelFromJson(json);

  Challenge toEntity() => Challenge(
    id: id,
    title: title,
    type: ChallengeType.fromWire(type),
    target: targetValue,
    startsAt: startsAt,
    endsAt: endsAt,
    participantCount: participantCount,
    description: descriptionMd,
    terms: termsMd,
    medals: [for (final medal in medals) medal.toEntity()],
    coverImageUrl: coverImageUrl,
    city: city,
    landmark: landmark,
    enrollment: enrollment?.toEntity(),
    blockedBy: blockedBy?.toEntity(),
  );
}

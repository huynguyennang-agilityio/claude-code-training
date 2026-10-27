import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/profile.dart';

part 'profile_model.freezed.dart';
part 'profile_model.g.dart';

/// The `Profile` shape of `docs/api/profile.md`. `toJson` keeps null values,
/// because `PUT` must send all nine keys.
@freezed
abstract class ProfileModel with _$ProfileModel {
  const factory ProfileModel({
    String? firstName,
    String? lastName,
    String? birthday,
    String? country,
    String? state,
    String? gender,
    required String unitSystem,
    double? heightCm,
    double? weightKg,
  }) = _ProfileModel;

  const ProfileModel._();

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  factory ProfileModel.fromEntity(Profile profile) => ProfileModel(
    firstName: profile.firstName,
    lastName: profile.lastName,
    birthday: profile.birthday == null ? null : _isoDate(profile.birthday!),
    country: profile.country,
    state: profile.state,
    gender: profile.gender?.wire,
    unitSystem: profile.unitSystem.wire,
    heightCm: profile.heightCm,
    weightKg: profile.weightKg,
  );

  Profile toEntity() => Profile(
    firstName: firstName,
    lastName: lastName,
    birthday: birthday == null
        ? null
        : DateTime.tryParse('${birthday}T00:00:00Z'),
    country: country,
    state: state,
    gender: Gender.fromWire(gender),
    unitSystem: UnitSystem.fromWire(unitSystem),
    heightCm: heightCm,
    weightKg: weightKg,
  );
}

String _isoDate(DateTime date) {
  final utc = DateTime.utc(date.year, date.month, date.day);
  return utc.toIso8601String().substring(0, 10);
}

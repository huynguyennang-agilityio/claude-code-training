// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) =>
    _ProfileModel(
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      birthday: json['birthday'] as String?,
      country: json['country'] as String?,
      state: json['state'] as String?,
      gender: json['gender'] as String?,
      unitSystem: json['unit_system'] as String,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ProfileModelToJson(_ProfileModel instance) =>
    <String, dynamic>{
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'birthday': instance.birthday,
      'country': instance.country,
      'state': instance.state,
      'gender': instance.gender,
      'unit_system': instance.unitSystem,
      'height_cm': instance.heightCm,
      'weight_kg': instance.weightKg,
    };

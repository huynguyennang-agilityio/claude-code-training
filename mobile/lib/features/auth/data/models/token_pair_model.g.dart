// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_pair_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TokenPairModel _$TokenPairModelFromJson(Map<String, dynamic> json) =>
    _TokenPairModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: _durationFromSeconds((json['expires_in'] as num).toInt()),
      tokenType: json['token_type'] == null
          ? 'bearer'
          : _bearerOnly(json['token_type'] as String),
    );

Map<String, dynamic> _$TokenPairModelToJson(_TokenPairModel instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'expires_in': _durationToSeconds(instance.expiresIn),
      'token_type': instance.tokenType,
    };

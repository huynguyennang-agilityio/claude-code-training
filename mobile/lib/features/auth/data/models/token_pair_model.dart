import 'package:freezed_annotation/freezed_annotation.dart';

part 'token_pair_model.freezed.dart';
part 'token_pair_model.g.dart';

/// The API's `TokenPair` shape (`docs/api/auth.md`).
@freezed
abstract class TokenPairModel with _$TokenPairModel {
  const factory TokenPairModel({
    required String accessToken,
    required String refreshToken,

    /// How long the access token is valid from when it was issued, from
    /// `expires_in`. The contract says to use this instead of a fixed lifetime.
    @JsonKey(fromJson: _durationFromSeconds, toJson: _durationToSeconds)
    required Duration expiresIn,

    /// Always `bearer`; parsing any other value throws [FormatException].
    @JsonKey(fromJson: _bearerOnly) @Default('bearer') String tokenType,
  }) = _TokenPairModel;

  factory TokenPairModel.fromJson(Map<String, dynamic> json) =>
      _$TokenPairModelFromJson(json);
}

String _bearerOnly(String tokenType) {
  if (tokenType.toLowerCase() != 'bearer') {
    throw FormatException('Unsupported token_type: $tokenType');
  }
  return tokenType;
}

Duration _durationFromSeconds(int seconds) => Duration(seconds: seconds);

int _durationToSeconds(Duration duration) => duration.inSeconds;

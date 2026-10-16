import 'package:freezed_annotation/freezed_annotation.dart';

import 'auth_user_model.dart';
import 'token_pair_model.dart';

part 'auth_session_model.freezed.dart';
part 'auth_session_model.g.dart';

/// The result of signing up or signing in, and what the app stores locally.
@freezed
abstract class AuthSessionModel with _$AuthSessionModel {
  const factory AuthSessionModel({
    required AuthUserModel user,
    required TokenPairModel tokens,
  }) = _AuthSessionModel;

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionModelFromJson(json);
}

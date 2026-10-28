// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'token_pair_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TokenPairModel {

 String get accessToken; String get refreshToken;/// How long the access token is valid from when it was issued, from
/// `expires_in`. The contract says to use this instead of a fixed lifetime.
@JsonKey(fromJson: _durationFromSeconds, toJson: _durationToSeconds) Duration get expiresIn;/// Always `bearer`; parsing any other value throws [FormatException].
@JsonKey(fromJson: _bearerOnly) String get tokenType;
/// Create a copy of TokenPairModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TokenPairModelCopyWith<TokenPairModel> get copyWith => _$TokenPairModelCopyWithImpl<TokenPairModel>(this as TokenPairModel, _$identity);

  /// Serializes this TokenPairModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TokenPairModel&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn)&&(identical(other.tokenType, tokenType) || other.tokenType == tokenType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,expiresIn,tokenType);

@override
String toString() {
  return 'TokenPairModel(accessToken: $accessToken, refreshToken: $refreshToken, expiresIn: $expiresIn, tokenType: $tokenType)';
}


}

/// @nodoc
abstract mixin class $TokenPairModelCopyWith<$Res>  {
  factory $TokenPairModelCopyWith(TokenPairModel value, $Res Function(TokenPairModel) _then) = _$TokenPairModelCopyWithImpl;
@useResult
$Res call({
 String accessToken, String refreshToken,@JsonKey(fromJson: _durationFromSeconds, toJson: _durationToSeconds) Duration expiresIn,@JsonKey(fromJson: _bearerOnly) String tokenType
});




}
/// @nodoc
class _$TokenPairModelCopyWithImpl<$Res>
    implements $TokenPairModelCopyWith<$Res> {
  _$TokenPairModelCopyWithImpl(this._self, this._then);

  final TokenPairModel _self;
  final $Res Function(TokenPairModel) _then;

/// Create a copy of TokenPairModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? refreshToken = null,Object? expiresIn = null,Object? tokenType = null,}) {
  return _then(_self.copyWith(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as Duration,tokenType: null == tokenType ? _self.tokenType : tokenType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TokenPairModel].
extension TokenPairModelPatterns on TokenPairModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TokenPairModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TokenPairModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TokenPairModel value)  $default,){
final _that = this;
switch (_that) {
case _TokenPairModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TokenPairModel value)?  $default,){
final _that = this;
switch (_that) {
case _TokenPairModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken, @JsonKey(fromJson: _durationFromSeconds, toJson: _durationToSeconds)  Duration expiresIn, @JsonKey(fromJson: _bearerOnly)  String tokenType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TokenPairModel() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.expiresIn,_that.tokenType);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken, @JsonKey(fromJson: _durationFromSeconds, toJson: _durationToSeconds)  Duration expiresIn, @JsonKey(fromJson: _bearerOnly)  String tokenType)  $default,) {final _that = this;
switch (_that) {
case _TokenPairModel():
return $default(_that.accessToken,_that.refreshToken,_that.expiresIn,_that.tokenType);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accessToken,  String refreshToken, @JsonKey(fromJson: _durationFromSeconds, toJson: _durationToSeconds)  Duration expiresIn, @JsonKey(fromJson: _bearerOnly)  String tokenType)?  $default,) {final _that = this;
switch (_that) {
case _TokenPairModel() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.expiresIn,_that.tokenType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TokenPairModel implements TokenPairModel {
  const _TokenPairModel({required this.accessToken, required this.refreshToken, @JsonKey(fromJson: _durationFromSeconds, toJson: _durationToSeconds) required this.expiresIn, @JsonKey(fromJson: _bearerOnly) this.tokenType = 'bearer'});
  factory _TokenPairModel.fromJson(Map<String, dynamic> json) => _$TokenPairModelFromJson(json);

@override final  String accessToken;
@override final  String refreshToken;
/// How long the access token is valid from when it was issued, from
/// `expires_in`. The contract says to use this instead of a fixed lifetime.
@override@JsonKey(fromJson: _durationFromSeconds, toJson: _durationToSeconds) final  Duration expiresIn;
/// Always `bearer`; parsing any other value throws [FormatException].
@override@JsonKey(fromJson: _bearerOnly) final  String tokenType;

/// Create a copy of TokenPairModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TokenPairModelCopyWith<_TokenPairModel> get copyWith => __$TokenPairModelCopyWithImpl<_TokenPairModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TokenPairModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TokenPairModel&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn)&&(identical(other.tokenType, tokenType) || other.tokenType == tokenType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,expiresIn,tokenType);

@override
String toString() {
  return 'TokenPairModel(accessToken: $accessToken, refreshToken: $refreshToken, expiresIn: $expiresIn, tokenType: $tokenType)';
}


}

/// @nodoc
abstract mixin class _$TokenPairModelCopyWith<$Res> implements $TokenPairModelCopyWith<$Res> {
  factory _$TokenPairModelCopyWith(_TokenPairModel value, $Res Function(_TokenPairModel) _then) = __$TokenPairModelCopyWithImpl;
@override @useResult
$Res call({
 String accessToken, String refreshToken,@JsonKey(fromJson: _durationFromSeconds, toJson: _durationToSeconds) Duration expiresIn,@JsonKey(fromJson: _bearerOnly) String tokenType
});




}
/// @nodoc
class __$TokenPairModelCopyWithImpl<$Res>
    implements _$TokenPairModelCopyWith<$Res> {
  __$TokenPairModelCopyWithImpl(this._self, this._then);

  final _TokenPairModel _self;
  final $Res Function(_TokenPairModel) _then;

/// Create a copy of TokenPairModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? refreshToken = null,Object? expiresIn = null,Object? tokenType = null,}) {
  return _then(_TokenPairModel(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as Duration,tokenType: null == tokenType ? _self.tokenType : tokenType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

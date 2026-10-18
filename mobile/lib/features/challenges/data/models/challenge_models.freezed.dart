// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'challenge_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EnrollmentModel {

 String get status; DateTime get joinedAt;
/// Create a copy of EnrollmentModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnrollmentModelCopyWith<EnrollmentModel> get copyWith => _$EnrollmentModelCopyWithImpl<EnrollmentModel>(this as EnrollmentModel, _$identity);

  /// Serializes this EnrollmentModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EnrollmentModel&&(identical(other.status, status) || other.status == status)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,joinedAt);

@override
String toString() {
  return 'EnrollmentModel(status: $status, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $EnrollmentModelCopyWith<$Res>  {
  factory $EnrollmentModelCopyWith(EnrollmentModel value, $Res Function(EnrollmentModel) _then) = _$EnrollmentModelCopyWithImpl;
@useResult
$Res call({
 String status, DateTime joinedAt
});




}
/// @nodoc
class _$EnrollmentModelCopyWithImpl<$Res>
    implements $EnrollmentModelCopyWith<$Res> {
  _$EnrollmentModelCopyWithImpl(this._self, this._then);

  final EnrollmentModel _self;
  final $Res Function(EnrollmentModel) _then;

/// Create a copy of EnrollmentModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? joinedAt = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [EnrollmentModel].
extension EnrollmentModelPatterns on EnrollmentModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EnrollmentModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EnrollmentModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EnrollmentModel value)  $default,){
final _that = this;
switch (_that) {
case _EnrollmentModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EnrollmentModel value)?  $default,){
final _that = this;
switch (_that) {
case _EnrollmentModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  DateTime joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EnrollmentModel() when $default != null:
return $default(_that.status,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  DateTime joinedAt)  $default,) {final _that = this;
switch (_that) {
case _EnrollmentModel():
return $default(_that.status,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  DateTime joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _EnrollmentModel() when $default != null:
return $default(_that.status,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EnrollmentModel extends EnrollmentModel {
  const _EnrollmentModel({required this.status, required this.joinedAt}): super._();
  factory _EnrollmentModel.fromJson(Map<String, dynamic> json) => _$EnrollmentModelFromJson(json);

@override final  String status;
@override final  DateTime joinedAt;

/// Create a copy of EnrollmentModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EnrollmentModelCopyWith<_EnrollmentModel> get copyWith => __$EnrollmentModelCopyWithImpl<_EnrollmentModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EnrollmentModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EnrollmentModel&&(identical(other.status, status) || other.status == status)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,joinedAt);

@override
String toString() {
  return 'EnrollmentModel(status: $status, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$EnrollmentModelCopyWith<$Res> implements $EnrollmentModelCopyWith<$Res> {
  factory _$EnrollmentModelCopyWith(_EnrollmentModel value, $Res Function(_EnrollmentModel) _then) = __$EnrollmentModelCopyWithImpl;
@override @useResult
$Res call({
 String status, DateTime joinedAt
});




}
/// @nodoc
class __$EnrollmentModelCopyWithImpl<$Res>
    implements _$EnrollmentModelCopyWith<$Res> {
  __$EnrollmentModelCopyWithImpl(this._self, this._then);

  final _EnrollmentModel _self;
  final $Res Function(_EnrollmentModel) _then;

/// Create a copy of EnrollmentModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? joinedAt = null,}) {
  return _then(_EnrollmentModel(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$MedalModel {

 String get tier; String get name; int get thresholdValue; String get imageUrl;
/// Create a copy of MedalModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedalModelCopyWith<MedalModel> get copyWith => _$MedalModelCopyWithImpl<MedalModel>(this as MedalModel, _$identity);

  /// Serializes this MedalModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedalModel&&(identical(other.tier, tier) || other.tier == tier)&&(identical(other.name, name) || other.name == name)&&(identical(other.thresholdValue, thresholdValue) || other.thresholdValue == thresholdValue)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tier,name,thresholdValue,imageUrl);

@override
String toString() {
  return 'MedalModel(tier: $tier, name: $name, thresholdValue: $thresholdValue, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class $MedalModelCopyWith<$Res>  {
  factory $MedalModelCopyWith(MedalModel value, $Res Function(MedalModel) _then) = _$MedalModelCopyWithImpl;
@useResult
$Res call({
 String tier, String name, int thresholdValue, String imageUrl
});




}
/// @nodoc
class _$MedalModelCopyWithImpl<$Res>
    implements $MedalModelCopyWith<$Res> {
  _$MedalModelCopyWithImpl(this._self, this._then);

  final MedalModel _self;
  final $Res Function(MedalModel) _then;

/// Create a copy of MedalModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tier = null,Object? name = null,Object? thresholdValue = null,Object? imageUrl = null,}) {
  return _then(_self.copyWith(
tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,thresholdValue: null == thresholdValue ? _self.thresholdValue : thresholdValue // ignore: cast_nullable_to_non_nullable
as int,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MedalModel].
extension MedalModelPatterns on MedalModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedalModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedalModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedalModel value)  $default,){
final _that = this;
switch (_that) {
case _MedalModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedalModel value)?  $default,){
final _that = this;
switch (_that) {
case _MedalModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tier,  String name,  int thresholdValue,  String imageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedalModel() when $default != null:
return $default(_that.tier,_that.name,_that.thresholdValue,_that.imageUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tier,  String name,  int thresholdValue,  String imageUrl)  $default,) {final _that = this;
switch (_that) {
case _MedalModel():
return $default(_that.tier,_that.name,_that.thresholdValue,_that.imageUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tier,  String name,  int thresholdValue,  String imageUrl)?  $default,) {final _that = this;
switch (_that) {
case _MedalModel() when $default != null:
return $default(_that.tier,_that.name,_that.thresholdValue,_that.imageUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedalModel extends MedalModel {
  const _MedalModel({required this.tier, required this.name, required this.thresholdValue, required this.imageUrl}): super._();
  factory _MedalModel.fromJson(Map<String, dynamic> json) => _$MedalModelFromJson(json);

@override final  String tier;
@override final  String name;
@override final  int thresholdValue;
@override final  String imageUrl;

/// Create a copy of MedalModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedalModelCopyWith<_MedalModel> get copyWith => __$MedalModelCopyWithImpl<_MedalModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedalModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedalModel&&(identical(other.tier, tier) || other.tier == tier)&&(identical(other.name, name) || other.name == name)&&(identical(other.thresholdValue, thresholdValue) || other.thresholdValue == thresholdValue)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tier,name,thresholdValue,imageUrl);

@override
String toString() {
  return 'MedalModel(tier: $tier, name: $name, thresholdValue: $thresholdValue, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class _$MedalModelCopyWith<$Res> implements $MedalModelCopyWith<$Res> {
  factory _$MedalModelCopyWith(_MedalModel value, $Res Function(_MedalModel) _then) = __$MedalModelCopyWithImpl;
@override @useResult
$Res call({
 String tier, String name, int thresholdValue, String imageUrl
});




}
/// @nodoc
class __$MedalModelCopyWithImpl<$Res>
    implements _$MedalModelCopyWith<$Res> {
  __$MedalModelCopyWithImpl(this._self, this._then);

  final _MedalModel _self;
  final $Res Function(_MedalModel) _then;

/// Create a copy of MedalModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tier = null,Object? name = null,Object? thresholdValue = null,Object? imageUrl = null,}) {
  return _then(_MedalModel(
tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,thresholdValue: null == thresholdValue ? _self.thresholdValue : thresholdValue // ignore: cast_nullable_to_non_nullable
as int,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$BlockedByModel {

 int get id; String get title;
/// Create a copy of BlockedByModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlockedByModelCopyWith<BlockedByModel> get copyWith => _$BlockedByModelCopyWithImpl<BlockedByModel>(this as BlockedByModel, _$identity);

  /// Serializes this BlockedByModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlockedByModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title);

@override
String toString() {
  return 'BlockedByModel(id: $id, title: $title)';
}


}

/// @nodoc
abstract mixin class $BlockedByModelCopyWith<$Res>  {
  factory $BlockedByModelCopyWith(BlockedByModel value, $Res Function(BlockedByModel) _then) = _$BlockedByModelCopyWithImpl;
@useResult
$Res call({
 int id, String title
});




}
/// @nodoc
class _$BlockedByModelCopyWithImpl<$Res>
    implements $BlockedByModelCopyWith<$Res> {
  _$BlockedByModelCopyWithImpl(this._self, this._then);

  final BlockedByModel _self;
  final $Res Function(BlockedByModel) _then;

/// Create a copy of BlockedByModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BlockedByModel].
extension BlockedByModelPatterns on BlockedByModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlockedByModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlockedByModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlockedByModel value)  $default,){
final _that = this;
switch (_that) {
case _BlockedByModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlockedByModel value)?  $default,){
final _that = this;
switch (_that) {
case _BlockedByModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlockedByModel() when $default != null:
return $default(_that.id,_that.title);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title)  $default,) {final _that = this;
switch (_that) {
case _BlockedByModel():
return $default(_that.id,_that.title);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title)?  $default,) {final _that = this;
switch (_that) {
case _BlockedByModel() when $default != null:
return $default(_that.id,_that.title);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BlockedByModel extends BlockedByModel {
  const _BlockedByModel({required this.id, required this.title}): super._();
  factory _BlockedByModel.fromJson(Map<String, dynamic> json) => _$BlockedByModelFromJson(json);

@override final  int id;
@override final  String title;

/// Create a copy of BlockedByModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlockedByModelCopyWith<_BlockedByModel> get copyWith => __$BlockedByModelCopyWithImpl<_BlockedByModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BlockedByModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlockedByModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title);

@override
String toString() {
  return 'BlockedByModel(id: $id, title: $title)';
}


}

/// @nodoc
abstract mixin class _$BlockedByModelCopyWith<$Res> implements $BlockedByModelCopyWith<$Res> {
  factory _$BlockedByModelCopyWith(_BlockedByModel value, $Res Function(_BlockedByModel) _then) = __$BlockedByModelCopyWithImpl;
@override @useResult
$Res call({
 int id, String title
});




}
/// @nodoc
class __$BlockedByModelCopyWithImpl<$Res>
    implements _$BlockedByModelCopyWith<$Res> {
  __$BlockedByModelCopyWithImpl(this._self, this._then);

  final _BlockedByModel _self;
  final $Res Function(_BlockedByModel) _then;

/// Create a copy of BlockedByModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,}) {
  return _then(_BlockedByModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ChallengeSummaryModel {

 int get id; String get title; String get type; int get targetValue; DateTime get startsAt; DateTime get endsAt; int get participantCount; String? get coverImageUrl; String? get city; String? get landmark; EnrollmentModel? get enrollment;
/// Create a copy of ChallengeSummaryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChallengeSummaryModelCopyWith<ChallengeSummaryModel> get copyWith => _$ChallengeSummaryModelCopyWithImpl<ChallengeSummaryModel>(this as ChallengeSummaryModel, _$identity);

  /// Serializes this ChallengeSummaryModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChallengeSummaryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.type, type) || other.type == type)&&(identical(other.targetValue, targetValue) || other.targetValue == targetValue)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.city, city) || other.city == city)&&(identical(other.landmark, landmark) || other.landmark == landmark)&&(identical(other.enrollment, enrollment) || other.enrollment == enrollment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,type,targetValue,startsAt,endsAt,participantCount,coverImageUrl,city,landmark,enrollment);

@override
String toString() {
  return 'ChallengeSummaryModel(id: $id, title: $title, type: $type, targetValue: $targetValue, startsAt: $startsAt, endsAt: $endsAt, participantCount: $participantCount, coverImageUrl: $coverImageUrl, city: $city, landmark: $landmark, enrollment: $enrollment)';
}


}

/// @nodoc
abstract mixin class $ChallengeSummaryModelCopyWith<$Res>  {
  factory $ChallengeSummaryModelCopyWith(ChallengeSummaryModel value, $Res Function(ChallengeSummaryModel) _then) = _$ChallengeSummaryModelCopyWithImpl;
@useResult
$Res call({
 int id, String title, String type, int targetValue, DateTime startsAt, DateTime endsAt, int participantCount, String? coverImageUrl, String? city, String? landmark, EnrollmentModel? enrollment
});


$EnrollmentModelCopyWith<$Res>? get enrollment;

}
/// @nodoc
class _$ChallengeSummaryModelCopyWithImpl<$Res>
    implements $ChallengeSummaryModelCopyWith<$Res> {
  _$ChallengeSummaryModelCopyWithImpl(this._self, this._then);

  final ChallengeSummaryModel _self;
  final $Res Function(ChallengeSummaryModel) _then;

/// Create a copy of ChallengeSummaryModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? type = null,Object? targetValue = null,Object? startsAt = null,Object? endsAt = null,Object? participantCount = null,Object? coverImageUrl = freezed,Object? city = freezed,Object? landmark = freezed,Object? enrollment = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,targetValue: null == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as int,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,coverImageUrl: freezed == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,landmark: freezed == landmark ? _self.landmark : landmark // ignore: cast_nullable_to_non_nullable
as String?,enrollment: freezed == enrollment ? _self.enrollment : enrollment // ignore: cast_nullable_to_non_nullable
as EnrollmentModel?,
  ));
}
/// Create a copy of ChallengeSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EnrollmentModelCopyWith<$Res>? get enrollment {
    if (_self.enrollment == null) {
    return null;
  }

  return $EnrollmentModelCopyWith<$Res>(_self.enrollment!, (value) {
    return _then(_self.copyWith(enrollment: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChallengeSummaryModel].
extension ChallengeSummaryModelPatterns on ChallengeSummaryModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChallengeSummaryModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChallengeSummaryModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChallengeSummaryModel value)  $default,){
final _that = this;
switch (_that) {
case _ChallengeSummaryModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChallengeSummaryModel value)?  $default,){
final _that = this;
switch (_that) {
case _ChallengeSummaryModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String type,  int targetValue,  DateTime startsAt,  DateTime endsAt,  int participantCount,  String? coverImageUrl,  String? city,  String? landmark,  EnrollmentModel? enrollment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChallengeSummaryModel() when $default != null:
return $default(_that.id,_that.title,_that.type,_that.targetValue,_that.startsAt,_that.endsAt,_that.participantCount,_that.coverImageUrl,_that.city,_that.landmark,_that.enrollment);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String type,  int targetValue,  DateTime startsAt,  DateTime endsAt,  int participantCount,  String? coverImageUrl,  String? city,  String? landmark,  EnrollmentModel? enrollment)  $default,) {final _that = this;
switch (_that) {
case _ChallengeSummaryModel():
return $default(_that.id,_that.title,_that.type,_that.targetValue,_that.startsAt,_that.endsAt,_that.participantCount,_that.coverImageUrl,_that.city,_that.landmark,_that.enrollment);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String type,  int targetValue,  DateTime startsAt,  DateTime endsAt,  int participantCount,  String? coverImageUrl,  String? city,  String? landmark,  EnrollmentModel? enrollment)?  $default,) {final _that = this;
switch (_that) {
case _ChallengeSummaryModel() when $default != null:
return $default(_that.id,_that.title,_that.type,_that.targetValue,_that.startsAt,_that.endsAt,_that.participantCount,_that.coverImageUrl,_that.city,_that.landmark,_that.enrollment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChallengeSummaryModel extends ChallengeSummaryModel {
  const _ChallengeSummaryModel({required this.id, required this.title, required this.type, required this.targetValue, required this.startsAt, required this.endsAt, required this.participantCount, this.coverImageUrl, this.city, this.landmark, this.enrollment}): super._();
  factory _ChallengeSummaryModel.fromJson(Map<String, dynamic> json) => _$ChallengeSummaryModelFromJson(json);

@override final  int id;
@override final  String title;
@override final  String type;
@override final  int targetValue;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
@override final  int participantCount;
@override final  String? coverImageUrl;
@override final  String? city;
@override final  String? landmark;
@override final  EnrollmentModel? enrollment;

/// Create a copy of ChallengeSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChallengeSummaryModelCopyWith<_ChallengeSummaryModel> get copyWith => __$ChallengeSummaryModelCopyWithImpl<_ChallengeSummaryModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChallengeSummaryModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChallengeSummaryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.type, type) || other.type == type)&&(identical(other.targetValue, targetValue) || other.targetValue == targetValue)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.city, city) || other.city == city)&&(identical(other.landmark, landmark) || other.landmark == landmark)&&(identical(other.enrollment, enrollment) || other.enrollment == enrollment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,type,targetValue,startsAt,endsAt,participantCount,coverImageUrl,city,landmark,enrollment);

@override
String toString() {
  return 'ChallengeSummaryModel(id: $id, title: $title, type: $type, targetValue: $targetValue, startsAt: $startsAt, endsAt: $endsAt, participantCount: $participantCount, coverImageUrl: $coverImageUrl, city: $city, landmark: $landmark, enrollment: $enrollment)';
}


}

/// @nodoc
abstract mixin class _$ChallengeSummaryModelCopyWith<$Res> implements $ChallengeSummaryModelCopyWith<$Res> {
  factory _$ChallengeSummaryModelCopyWith(_ChallengeSummaryModel value, $Res Function(_ChallengeSummaryModel) _then) = __$ChallengeSummaryModelCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String type, int targetValue, DateTime startsAt, DateTime endsAt, int participantCount, String? coverImageUrl, String? city, String? landmark, EnrollmentModel? enrollment
});


@override $EnrollmentModelCopyWith<$Res>? get enrollment;

}
/// @nodoc
class __$ChallengeSummaryModelCopyWithImpl<$Res>
    implements _$ChallengeSummaryModelCopyWith<$Res> {
  __$ChallengeSummaryModelCopyWithImpl(this._self, this._then);

  final _ChallengeSummaryModel _self;
  final $Res Function(_ChallengeSummaryModel) _then;

/// Create a copy of ChallengeSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? type = null,Object? targetValue = null,Object? startsAt = null,Object? endsAt = null,Object? participantCount = null,Object? coverImageUrl = freezed,Object? city = freezed,Object? landmark = freezed,Object? enrollment = freezed,}) {
  return _then(_ChallengeSummaryModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,targetValue: null == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as int,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,coverImageUrl: freezed == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,landmark: freezed == landmark ? _self.landmark : landmark // ignore: cast_nullable_to_non_nullable
as String?,enrollment: freezed == enrollment ? _self.enrollment : enrollment // ignore: cast_nullable_to_non_nullable
as EnrollmentModel?,
  ));
}

/// Create a copy of ChallengeSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EnrollmentModelCopyWith<$Res>? get enrollment {
    if (_self.enrollment == null) {
    return null;
  }

  return $EnrollmentModelCopyWith<$Res>(_self.enrollment!, (value) {
    return _then(_self.copyWith(enrollment: value));
  });
}
}


/// @nodoc
mixin _$ChallengePageModel {

 List<ChallengeSummaryModel> get items; String? get nextCursor;
/// Create a copy of ChallengePageModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChallengePageModelCopyWith<ChallengePageModel> get copyWith => _$ChallengePageModelCopyWithImpl<ChallengePageModel>(this as ChallengePageModel, _$identity);

  /// Serializes this ChallengePageModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChallengePageModel&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),nextCursor);

@override
String toString() {
  return 'ChallengePageModel(items: $items, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class $ChallengePageModelCopyWith<$Res>  {
  factory $ChallengePageModelCopyWith(ChallengePageModel value, $Res Function(ChallengePageModel) _then) = _$ChallengePageModelCopyWithImpl;
@useResult
$Res call({
 List<ChallengeSummaryModel> items, String? nextCursor
});




}
/// @nodoc
class _$ChallengePageModelCopyWithImpl<$Res>
    implements $ChallengePageModelCopyWith<$Res> {
  _$ChallengePageModelCopyWithImpl(this._self, this._then);

  final ChallengePageModel _self;
  final $Res Function(ChallengePageModel) _then;

/// Create a copy of ChallengePageModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? nextCursor = freezed,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ChallengeSummaryModel>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChallengePageModel].
extension ChallengePageModelPatterns on ChallengePageModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChallengePageModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChallengePageModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChallengePageModel value)  $default,){
final _that = this;
switch (_that) {
case _ChallengePageModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChallengePageModel value)?  $default,){
final _that = this;
switch (_that) {
case _ChallengePageModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ChallengeSummaryModel> items,  String? nextCursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChallengePageModel() when $default != null:
return $default(_that.items,_that.nextCursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ChallengeSummaryModel> items,  String? nextCursor)  $default,) {final _that = this;
switch (_that) {
case _ChallengePageModel():
return $default(_that.items,_that.nextCursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ChallengeSummaryModel> items,  String? nextCursor)?  $default,) {final _that = this;
switch (_that) {
case _ChallengePageModel() when $default != null:
return $default(_that.items,_that.nextCursor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChallengePageModel extends ChallengePageModel {
  const _ChallengePageModel({required final  List<ChallengeSummaryModel> items, this.nextCursor}): _items = items,super._();
  factory _ChallengePageModel.fromJson(Map<String, dynamic> json) => _$ChallengePageModelFromJson(json);

 final  List<ChallengeSummaryModel> _items;
@override List<ChallengeSummaryModel> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  String? nextCursor;

/// Create a copy of ChallengePageModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChallengePageModelCopyWith<_ChallengePageModel> get copyWith => __$ChallengePageModelCopyWithImpl<_ChallengePageModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChallengePageModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChallengePageModel&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),nextCursor);

@override
String toString() {
  return 'ChallengePageModel(items: $items, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class _$ChallengePageModelCopyWith<$Res> implements $ChallengePageModelCopyWith<$Res> {
  factory _$ChallengePageModelCopyWith(_ChallengePageModel value, $Res Function(_ChallengePageModel) _then) = __$ChallengePageModelCopyWithImpl;
@override @useResult
$Res call({
 List<ChallengeSummaryModel> items, String? nextCursor
});




}
/// @nodoc
class __$ChallengePageModelCopyWithImpl<$Res>
    implements _$ChallengePageModelCopyWith<$Res> {
  __$ChallengePageModelCopyWithImpl(this._self, this._then);

  final _ChallengePageModel _self;
  final $Res Function(_ChallengePageModel) _then;

/// Create a copy of ChallengePageModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? nextCursor = freezed,}) {
  return _then(_ChallengePageModel(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ChallengeSummaryModel>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ChallengeModel {

 int get id; String get title; String get type; int get targetValue; String get descriptionMd; String get termsMd; DateTime get startsAt; DateTime get endsAt; List<MedalModel> get medals; int get participantCount; String? get coverImageUrl; String? get city; String? get landmark; EnrollmentModel? get enrollment; BlockedByModel? get blockedBy;
/// Create a copy of ChallengeModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChallengeModelCopyWith<ChallengeModel> get copyWith => _$ChallengeModelCopyWithImpl<ChallengeModel>(this as ChallengeModel, _$identity);

  /// Serializes this ChallengeModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChallengeModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.type, type) || other.type == type)&&(identical(other.targetValue, targetValue) || other.targetValue == targetValue)&&(identical(other.descriptionMd, descriptionMd) || other.descriptionMd == descriptionMd)&&(identical(other.termsMd, termsMd) || other.termsMd == termsMd)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&const DeepCollectionEquality().equals(other.medals, medals)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.city, city) || other.city == city)&&(identical(other.landmark, landmark) || other.landmark == landmark)&&(identical(other.enrollment, enrollment) || other.enrollment == enrollment)&&(identical(other.blockedBy, blockedBy) || other.blockedBy == blockedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,type,targetValue,descriptionMd,termsMd,startsAt,endsAt,const DeepCollectionEquality().hash(medals),participantCount,coverImageUrl,city,landmark,enrollment,blockedBy);

@override
String toString() {
  return 'ChallengeModel(id: $id, title: $title, type: $type, targetValue: $targetValue, descriptionMd: $descriptionMd, termsMd: $termsMd, startsAt: $startsAt, endsAt: $endsAt, medals: $medals, participantCount: $participantCount, coverImageUrl: $coverImageUrl, city: $city, landmark: $landmark, enrollment: $enrollment, blockedBy: $blockedBy)';
}


}

/// @nodoc
abstract mixin class $ChallengeModelCopyWith<$Res>  {
  factory $ChallengeModelCopyWith(ChallengeModel value, $Res Function(ChallengeModel) _then) = _$ChallengeModelCopyWithImpl;
@useResult
$Res call({
 int id, String title, String type, int targetValue, String descriptionMd, String termsMd, DateTime startsAt, DateTime endsAt, List<MedalModel> medals, int participantCount, String? coverImageUrl, String? city, String? landmark, EnrollmentModel? enrollment, BlockedByModel? blockedBy
});


$EnrollmentModelCopyWith<$Res>? get enrollment;$BlockedByModelCopyWith<$Res>? get blockedBy;

}
/// @nodoc
class _$ChallengeModelCopyWithImpl<$Res>
    implements $ChallengeModelCopyWith<$Res> {
  _$ChallengeModelCopyWithImpl(this._self, this._then);

  final ChallengeModel _self;
  final $Res Function(ChallengeModel) _then;

/// Create a copy of ChallengeModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? type = null,Object? targetValue = null,Object? descriptionMd = null,Object? termsMd = null,Object? startsAt = null,Object? endsAt = null,Object? medals = null,Object? participantCount = null,Object? coverImageUrl = freezed,Object? city = freezed,Object? landmark = freezed,Object? enrollment = freezed,Object? blockedBy = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,targetValue: null == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as int,descriptionMd: null == descriptionMd ? _self.descriptionMd : descriptionMd // ignore: cast_nullable_to_non_nullable
as String,termsMd: null == termsMd ? _self.termsMd : termsMd // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,medals: null == medals ? _self.medals : medals // ignore: cast_nullable_to_non_nullable
as List<MedalModel>,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,coverImageUrl: freezed == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,landmark: freezed == landmark ? _self.landmark : landmark // ignore: cast_nullable_to_non_nullable
as String?,enrollment: freezed == enrollment ? _self.enrollment : enrollment // ignore: cast_nullable_to_non_nullable
as EnrollmentModel?,blockedBy: freezed == blockedBy ? _self.blockedBy : blockedBy // ignore: cast_nullable_to_non_nullable
as BlockedByModel?,
  ));
}
/// Create a copy of ChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EnrollmentModelCopyWith<$Res>? get enrollment {
    if (_self.enrollment == null) {
    return null;
  }

  return $EnrollmentModelCopyWith<$Res>(_self.enrollment!, (value) {
    return _then(_self.copyWith(enrollment: value));
  });
}/// Create a copy of ChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockedByModelCopyWith<$Res>? get blockedBy {
    if (_self.blockedBy == null) {
    return null;
  }

  return $BlockedByModelCopyWith<$Res>(_self.blockedBy!, (value) {
    return _then(_self.copyWith(blockedBy: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChallengeModel].
extension ChallengeModelPatterns on ChallengeModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChallengeModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChallengeModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChallengeModel value)  $default,){
final _that = this;
switch (_that) {
case _ChallengeModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChallengeModel value)?  $default,){
final _that = this;
switch (_that) {
case _ChallengeModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String type,  int targetValue,  String descriptionMd,  String termsMd,  DateTime startsAt,  DateTime endsAt,  List<MedalModel> medals,  int participantCount,  String? coverImageUrl,  String? city,  String? landmark,  EnrollmentModel? enrollment,  BlockedByModel? blockedBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChallengeModel() when $default != null:
return $default(_that.id,_that.title,_that.type,_that.targetValue,_that.descriptionMd,_that.termsMd,_that.startsAt,_that.endsAt,_that.medals,_that.participantCount,_that.coverImageUrl,_that.city,_that.landmark,_that.enrollment,_that.blockedBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String type,  int targetValue,  String descriptionMd,  String termsMd,  DateTime startsAt,  DateTime endsAt,  List<MedalModel> medals,  int participantCount,  String? coverImageUrl,  String? city,  String? landmark,  EnrollmentModel? enrollment,  BlockedByModel? blockedBy)  $default,) {final _that = this;
switch (_that) {
case _ChallengeModel():
return $default(_that.id,_that.title,_that.type,_that.targetValue,_that.descriptionMd,_that.termsMd,_that.startsAt,_that.endsAt,_that.medals,_that.participantCount,_that.coverImageUrl,_that.city,_that.landmark,_that.enrollment,_that.blockedBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String type,  int targetValue,  String descriptionMd,  String termsMd,  DateTime startsAt,  DateTime endsAt,  List<MedalModel> medals,  int participantCount,  String? coverImageUrl,  String? city,  String? landmark,  EnrollmentModel? enrollment,  BlockedByModel? blockedBy)?  $default,) {final _that = this;
switch (_that) {
case _ChallengeModel() when $default != null:
return $default(_that.id,_that.title,_that.type,_that.targetValue,_that.descriptionMd,_that.termsMd,_that.startsAt,_that.endsAt,_that.medals,_that.participantCount,_that.coverImageUrl,_that.city,_that.landmark,_that.enrollment,_that.blockedBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChallengeModel extends ChallengeModel {
  const _ChallengeModel({required this.id, required this.title, required this.type, required this.targetValue, required this.descriptionMd, required this.termsMd, required this.startsAt, required this.endsAt, required final  List<MedalModel> medals, required this.participantCount, this.coverImageUrl, this.city, this.landmark, this.enrollment, this.blockedBy}): _medals = medals,super._();
  factory _ChallengeModel.fromJson(Map<String, dynamic> json) => _$ChallengeModelFromJson(json);

@override final  int id;
@override final  String title;
@override final  String type;
@override final  int targetValue;
@override final  String descriptionMd;
@override final  String termsMd;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
 final  List<MedalModel> _medals;
@override List<MedalModel> get medals {
  if (_medals is EqualUnmodifiableListView) return _medals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_medals);
}

@override final  int participantCount;
@override final  String? coverImageUrl;
@override final  String? city;
@override final  String? landmark;
@override final  EnrollmentModel? enrollment;
@override final  BlockedByModel? blockedBy;

/// Create a copy of ChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChallengeModelCopyWith<_ChallengeModel> get copyWith => __$ChallengeModelCopyWithImpl<_ChallengeModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChallengeModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChallengeModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.type, type) || other.type == type)&&(identical(other.targetValue, targetValue) || other.targetValue == targetValue)&&(identical(other.descriptionMd, descriptionMd) || other.descriptionMd == descriptionMd)&&(identical(other.termsMd, termsMd) || other.termsMd == termsMd)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&const DeepCollectionEquality().equals(other._medals, _medals)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.city, city) || other.city == city)&&(identical(other.landmark, landmark) || other.landmark == landmark)&&(identical(other.enrollment, enrollment) || other.enrollment == enrollment)&&(identical(other.blockedBy, blockedBy) || other.blockedBy == blockedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,type,targetValue,descriptionMd,termsMd,startsAt,endsAt,const DeepCollectionEquality().hash(_medals),participantCount,coverImageUrl,city,landmark,enrollment,blockedBy);

@override
String toString() {
  return 'ChallengeModel(id: $id, title: $title, type: $type, targetValue: $targetValue, descriptionMd: $descriptionMd, termsMd: $termsMd, startsAt: $startsAt, endsAt: $endsAt, medals: $medals, participantCount: $participantCount, coverImageUrl: $coverImageUrl, city: $city, landmark: $landmark, enrollment: $enrollment, blockedBy: $blockedBy)';
}


}

/// @nodoc
abstract mixin class _$ChallengeModelCopyWith<$Res> implements $ChallengeModelCopyWith<$Res> {
  factory _$ChallengeModelCopyWith(_ChallengeModel value, $Res Function(_ChallengeModel) _then) = __$ChallengeModelCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String type, int targetValue, String descriptionMd, String termsMd, DateTime startsAt, DateTime endsAt, List<MedalModel> medals, int participantCount, String? coverImageUrl, String? city, String? landmark, EnrollmentModel? enrollment, BlockedByModel? blockedBy
});


@override $EnrollmentModelCopyWith<$Res>? get enrollment;@override $BlockedByModelCopyWith<$Res>? get blockedBy;

}
/// @nodoc
class __$ChallengeModelCopyWithImpl<$Res>
    implements _$ChallengeModelCopyWith<$Res> {
  __$ChallengeModelCopyWithImpl(this._self, this._then);

  final _ChallengeModel _self;
  final $Res Function(_ChallengeModel) _then;

/// Create a copy of ChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? type = null,Object? targetValue = null,Object? descriptionMd = null,Object? termsMd = null,Object? startsAt = null,Object? endsAt = null,Object? medals = null,Object? participantCount = null,Object? coverImageUrl = freezed,Object? city = freezed,Object? landmark = freezed,Object? enrollment = freezed,Object? blockedBy = freezed,}) {
  return _then(_ChallengeModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,targetValue: null == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as int,descriptionMd: null == descriptionMd ? _self.descriptionMd : descriptionMd // ignore: cast_nullable_to_non_nullable
as String,termsMd: null == termsMd ? _self.termsMd : termsMd // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,medals: null == medals ? _self._medals : medals // ignore: cast_nullable_to_non_nullable
as List<MedalModel>,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,coverImageUrl: freezed == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,landmark: freezed == landmark ? _self.landmark : landmark // ignore: cast_nullable_to_non_nullable
as String?,enrollment: freezed == enrollment ? _self.enrollment : enrollment // ignore: cast_nullable_to_non_nullable
as EnrollmentModel?,blockedBy: freezed == blockedBy ? _self.blockedBy : blockedBy // ignore: cast_nullable_to_non_nullable
as BlockedByModel?,
  ));
}

/// Create a copy of ChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EnrollmentModelCopyWith<$Res>? get enrollment {
    if (_self.enrollment == null) {
    return null;
  }

  return $EnrollmentModelCopyWith<$Res>(_self.enrollment!, (value) {
    return _then(_self.copyWith(enrollment: value));
  });
}/// Create a copy of ChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlockedByModelCopyWith<$Res>? get blockedBy {
    if (_self.blockedBy == null) {
    return null;
  }

  return $BlockedByModelCopyWith<$Res>(_self.blockedBy!, (value) {
    return _then(_self.copyWith(blockedBy: value));
  });
}
}

// dart format on

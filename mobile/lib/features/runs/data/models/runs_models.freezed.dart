// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'runs_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProgressModel {

 int get currentValue; int get targetValue; int get percent; bool get tracked; bool get started;
/// Create a copy of ProgressModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProgressModelCopyWith<ProgressModel> get copyWith => _$ProgressModelCopyWithImpl<ProgressModel>(this as ProgressModel, _$identity);

  /// Serializes this ProgressModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProgressModel&&(identical(other.currentValue, currentValue) || other.currentValue == currentValue)&&(identical(other.targetValue, targetValue) || other.targetValue == targetValue)&&(identical(other.percent, percent) || other.percent == percent)&&(identical(other.tracked, tracked) || other.tracked == tracked)&&(identical(other.started, started) || other.started == started));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentValue,targetValue,percent,tracked,started);

@override
String toString() {
  return 'ProgressModel(currentValue: $currentValue, targetValue: $targetValue, percent: $percent, tracked: $tracked, started: $started)';
}


}

/// @nodoc
abstract mixin class $ProgressModelCopyWith<$Res>  {
  factory $ProgressModelCopyWith(ProgressModel value, $Res Function(ProgressModel) _then) = _$ProgressModelCopyWithImpl;
@useResult
$Res call({
 int currentValue, int targetValue, int percent, bool tracked, bool started
});




}
/// @nodoc
class _$ProgressModelCopyWithImpl<$Res>
    implements $ProgressModelCopyWith<$Res> {
  _$ProgressModelCopyWithImpl(this._self, this._then);

  final ProgressModel _self;
  final $Res Function(ProgressModel) _then;

/// Create a copy of ProgressModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentValue = null,Object? targetValue = null,Object? percent = null,Object? tracked = null,Object? started = null,}) {
  return _then(_self.copyWith(
currentValue: null == currentValue ? _self.currentValue : currentValue // ignore: cast_nullable_to_non_nullable
as int,targetValue: null == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as int,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as int,tracked: null == tracked ? _self.tracked : tracked // ignore: cast_nullable_to_non_nullable
as bool,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProgressModel].
extension ProgressModelPatterns on ProgressModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProgressModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProgressModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProgressModel value)  $default,){
final _that = this;
switch (_that) {
case _ProgressModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProgressModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProgressModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int currentValue,  int targetValue,  int percent,  bool tracked,  bool started)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProgressModel() when $default != null:
return $default(_that.currentValue,_that.targetValue,_that.percent,_that.tracked,_that.started);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int currentValue,  int targetValue,  int percent,  bool tracked,  bool started)  $default,) {final _that = this;
switch (_that) {
case _ProgressModel():
return $default(_that.currentValue,_that.targetValue,_that.percent,_that.tracked,_that.started);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int currentValue,  int targetValue,  int percent,  bool tracked,  bool started)?  $default,) {final _that = this;
switch (_that) {
case _ProgressModel() when $default != null:
return $default(_that.currentValue,_that.targetValue,_that.percent,_that.tracked,_that.started);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProgressModel extends ProgressModel {
  const _ProgressModel({required this.currentValue, required this.targetValue, required this.percent, required this.tracked, required this.started}): super._();
  factory _ProgressModel.fromJson(Map<String, dynamic> json) => _$ProgressModelFromJson(json);

@override final  int currentValue;
@override final  int targetValue;
@override final  int percent;
@override final  bool tracked;
@override final  bool started;

/// Create a copy of ProgressModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProgressModelCopyWith<_ProgressModel> get copyWith => __$ProgressModelCopyWithImpl<_ProgressModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProgressModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProgressModel&&(identical(other.currentValue, currentValue) || other.currentValue == currentValue)&&(identical(other.targetValue, targetValue) || other.targetValue == targetValue)&&(identical(other.percent, percent) || other.percent == percent)&&(identical(other.tracked, tracked) || other.tracked == tracked)&&(identical(other.started, started) || other.started == started));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentValue,targetValue,percent,tracked,started);

@override
String toString() {
  return 'ProgressModel(currentValue: $currentValue, targetValue: $targetValue, percent: $percent, tracked: $tracked, started: $started)';
}


}

/// @nodoc
abstract mixin class _$ProgressModelCopyWith<$Res> implements $ProgressModelCopyWith<$Res> {
  factory _$ProgressModelCopyWith(_ProgressModel value, $Res Function(_ProgressModel) _then) = __$ProgressModelCopyWithImpl;
@override @useResult
$Res call({
 int currentValue, int targetValue, int percent, bool tracked, bool started
});




}
/// @nodoc
class __$ProgressModelCopyWithImpl<$Res>
    implements _$ProgressModelCopyWith<$Res> {
  __$ProgressModelCopyWithImpl(this._self, this._then);

  final _ProgressModel _self;
  final $Res Function(_ProgressModel) _then;

/// Create a copy of ProgressModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentValue = null,Object? targetValue = null,Object? percent = null,Object? tracked = null,Object? started = null,}) {
  return _then(_ProgressModel(
currentValue: null == currentValue ? _self.currentValue : currentValue // ignore: cast_nullable_to_non_nullable
as int,targetValue: null == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as int,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as int,tracked: null == tracked ? _self.tracked : tracked // ignore: cast_nullable_to_non_nullable
as bool,started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$MyChallengeModel {

 ChallengeSummaryModel get challenge; ProgressModel get progress;
/// Create a copy of MyChallengeModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MyChallengeModelCopyWith<MyChallengeModel> get copyWith => _$MyChallengeModelCopyWithImpl<MyChallengeModel>(this as MyChallengeModel, _$identity);

  /// Serializes this MyChallengeModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MyChallengeModel&&(identical(other.challenge, challenge) || other.challenge == challenge)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,challenge,progress);

@override
String toString() {
  return 'MyChallengeModel(challenge: $challenge, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $MyChallengeModelCopyWith<$Res>  {
  factory $MyChallengeModelCopyWith(MyChallengeModel value, $Res Function(MyChallengeModel) _then) = _$MyChallengeModelCopyWithImpl;
@useResult
$Res call({
 ChallengeSummaryModel challenge, ProgressModel progress
});


$ChallengeSummaryModelCopyWith<$Res> get challenge;$ProgressModelCopyWith<$Res> get progress;

}
/// @nodoc
class _$MyChallengeModelCopyWithImpl<$Res>
    implements $MyChallengeModelCopyWith<$Res> {
  _$MyChallengeModelCopyWithImpl(this._self, this._then);

  final MyChallengeModel _self;
  final $Res Function(MyChallengeModel) _then;

/// Create a copy of MyChallengeModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? challenge = null,Object? progress = null,}) {
  return _then(_self.copyWith(
challenge: null == challenge ? _self.challenge : challenge // ignore: cast_nullable_to_non_nullable
as ChallengeSummaryModel,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ProgressModel,
  ));
}
/// Create a copy of MyChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChallengeSummaryModelCopyWith<$Res> get challenge {
  
  return $ChallengeSummaryModelCopyWith<$Res>(_self.challenge, (value) {
    return _then(_self.copyWith(challenge: value));
  });
}/// Create a copy of MyChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProgressModelCopyWith<$Res> get progress {
  
  return $ProgressModelCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}


/// Adds pattern-matching-related methods to [MyChallengeModel].
extension MyChallengeModelPatterns on MyChallengeModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MyChallengeModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MyChallengeModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MyChallengeModel value)  $default,){
final _that = this;
switch (_that) {
case _MyChallengeModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MyChallengeModel value)?  $default,){
final _that = this;
switch (_that) {
case _MyChallengeModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ChallengeSummaryModel challenge,  ProgressModel progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MyChallengeModel() when $default != null:
return $default(_that.challenge,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ChallengeSummaryModel challenge,  ProgressModel progress)  $default,) {final _that = this;
switch (_that) {
case _MyChallengeModel():
return $default(_that.challenge,_that.progress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ChallengeSummaryModel challenge,  ProgressModel progress)?  $default,) {final _that = this;
switch (_that) {
case _MyChallengeModel() when $default != null:
return $default(_that.challenge,_that.progress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MyChallengeModel extends MyChallengeModel {
  const _MyChallengeModel({required this.challenge, required this.progress}): super._();
  factory _MyChallengeModel.fromJson(Map<String, dynamic> json) => _$MyChallengeModelFromJson(json);

@override final  ChallengeSummaryModel challenge;
@override final  ProgressModel progress;

/// Create a copy of MyChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MyChallengeModelCopyWith<_MyChallengeModel> get copyWith => __$MyChallengeModelCopyWithImpl<_MyChallengeModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MyChallengeModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MyChallengeModel&&(identical(other.challenge, challenge) || other.challenge == challenge)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,challenge,progress);

@override
String toString() {
  return 'MyChallengeModel(challenge: $challenge, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$MyChallengeModelCopyWith<$Res> implements $MyChallengeModelCopyWith<$Res> {
  factory _$MyChallengeModelCopyWith(_MyChallengeModel value, $Res Function(_MyChallengeModel) _then) = __$MyChallengeModelCopyWithImpl;
@override @useResult
$Res call({
 ChallengeSummaryModel challenge, ProgressModel progress
});


@override $ChallengeSummaryModelCopyWith<$Res> get challenge;@override $ProgressModelCopyWith<$Res> get progress;

}
/// @nodoc
class __$MyChallengeModelCopyWithImpl<$Res>
    implements _$MyChallengeModelCopyWith<$Res> {
  __$MyChallengeModelCopyWithImpl(this._self, this._then);

  final _MyChallengeModel _self;
  final $Res Function(_MyChallengeModel) _then;

/// Create a copy of MyChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? challenge = null,Object? progress = null,}) {
  return _then(_MyChallengeModel(
challenge: null == challenge ? _self.challenge : challenge // ignore: cast_nullable_to_non_nullable
as ChallengeSummaryModel,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ProgressModel,
  ));
}

/// Create a copy of MyChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChallengeSummaryModelCopyWith<$Res> get challenge {
  
  return $ChallengeSummaryModelCopyWith<$Res>(_self.challenge, (value) {
    return _then(_self.copyWith(challenge: value));
  });
}/// Create a copy of MyChallengeModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProgressModelCopyWith<$Res> get progress {
  
  return $ProgressModelCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}


/// @nodoc
mixin _$MyChallengePageModel {

 List<MyChallengeModel> get items; String? get nextCursor;
/// Create a copy of MyChallengePageModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MyChallengePageModelCopyWith<MyChallengePageModel> get copyWith => _$MyChallengePageModelCopyWithImpl<MyChallengePageModel>(this as MyChallengePageModel, _$identity);

  /// Serializes this MyChallengePageModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MyChallengePageModel&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),nextCursor);

@override
String toString() {
  return 'MyChallengePageModel(items: $items, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class $MyChallengePageModelCopyWith<$Res>  {
  factory $MyChallengePageModelCopyWith(MyChallengePageModel value, $Res Function(MyChallengePageModel) _then) = _$MyChallengePageModelCopyWithImpl;
@useResult
$Res call({
 List<MyChallengeModel> items, String? nextCursor
});




}
/// @nodoc
class _$MyChallengePageModelCopyWithImpl<$Res>
    implements $MyChallengePageModelCopyWith<$Res> {
  _$MyChallengePageModelCopyWithImpl(this._self, this._then);

  final MyChallengePageModel _self;
  final $Res Function(MyChallengePageModel) _then;

/// Create a copy of MyChallengePageModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? nextCursor = freezed,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<MyChallengeModel>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MyChallengePageModel].
extension MyChallengePageModelPatterns on MyChallengePageModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MyChallengePageModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MyChallengePageModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MyChallengePageModel value)  $default,){
final _that = this;
switch (_that) {
case _MyChallengePageModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MyChallengePageModel value)?  $default,){
final _that = this;
switch (_that) {
case _MyChallengePageModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MyChallengeModel> items,  String? nextCursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MyChallengePageModel() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MyChallengeModel> items,  String? nextCursor)  $default,) {final _that = this;
switch (_that) {
case _MyChallengePageModel():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MyChallengeModel> items,  String? nextCursor)?  $default,) {final _that = this;
switch (_that) {
case _MyChallengePageModel() when $default != null:
return $default(_that.items,_that.nextCursor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MyChallengePageModel extends MyChallengePageModel {
  const _MyChallengePageModel({required final  List<MyChallengeModel> items, this.nextCursor}): _items = items,super._();
  factory _MyChallengePageModel.fromJson(Map<String, dynamic> json) => _$MyChallengePageModelFromJson(json);

 final  List<MyChallengeModel> _items;
@override List<MyChallengeModel> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  String? nextCursor;

/// Create a copy of MyChallengePageModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MyChallengePageModelCopyWith<_MyChallengePageModel> get copyWith => __$MyChallengePageModelCopyWithImpl<_MyChallengePageModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MyChallengePageModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MyChallengePageModel&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),nextCursor);

@override
String toString() {
  return 'MyChallengePageModel(items: $items, nextCursor: $nextCursor)';
}


}

/// @nodoc
abstract mixin class _$MyChallengePageModelCopyWith<$Res> implements $MyChallengePageModelCopyWith<$Res> {
  factory _$MyChallengePageModelCopyWith(_MyChallengePageModel value, $Res Function(_MyChallengePageModel) _then) = __$MyChallengePageModelCopyWithImpl;
@override @useResult
$Res call({
 List<MyChallengeModel> items, String? nextCursor
});




}
/// @nodoc
class __$MyChallengePageModelCopyWithImpl<$Res>
    implements _$MyChallengePageModelCopyWith<$Res> {
  __$MyChallengePageModelCopyWithImpl(this._self, this._then);

  final _MyChallengePageModel _self;
  final $Res Function(_MyChallengePageModel) _then;

/// Create a copy of MyChallengePageModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? nextCursor = freezed,}) {
  return _then(_MyChallengePageModel(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<MyChallengeModel>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$StepSyncResultModel {

 int get accepted; int get ignored;
/// Create a copy of StepSyncResultModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StepSyncResultModelCopyWith<StepSyncResultModel> get copyWith => _$StepSyncResultModelCopyWithImpl<StepSyncResultModel>(this as StepSyncResultModel, _$identity);

  /// Serializes this StepSyncResultModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StepSyncResultModel&&(identical(other.accepted, accepted) || other.accepted == accepted)&&(identical(other.ignored, ignored) || other.ignored == ignored));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accepted,ignored);

@override
String toString() {
  return 'StepSyncResultModel(accepted: $accepted, ignored: $ignored)';
}


}

/// @nodoc
abstract mixin class $StepSyncResultModelCopyWith<$Res>  {
  factory $StepSyncResultModelCopyWith(StepSyncResultModel value, $Res Function(StepSyncResultModel) _then) = _$StepSyncResultModelCopyWithImpl;
@useResult
$Res call({
 int accepted, int ignored
});




}
/// @nodoc
class _$StepSyncResultModelCopyWithImpl<$Res>
    implements $StepSyncResultModelCopyWith<$Res> {
  _$StepSyncResultModelCopyWithImpl(this._self, this._then);

  final StepSyncResultModel _self;
  final $Res Function(StepSyncResultModel) _then;

/// Create a copy of StepSyncResultModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accepted = null,Object? ignored = null,}) {
  return _then(_self.copyWith(
accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as int,ignored: null == ignored ? _self.ignored : ignored // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [StepSyncResultModel].
extension StepSyncResultModelPatterns on StepSyncResultModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StepSyncResultModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StepSyncResultModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StepSyncResultModel value)  $default,){
final _that = this;
switch (_that) {
case _StepSyncResultModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StepSyncResultModel value)?  $default,){
final _that = this;
switch (_that) {
case _StepSyncResultModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int accepted,  int ignored)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StepSyncResultModel() when $default != null:
return $default(_that.accepted,_that.ignored);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int accepted,  int ignored)  $default,) {final _that = this;
switch (_that) {
case _StepSyncResultModel():
return $default(_that.accepted,_that.ignored);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int accepted,  int ignored)?  $default,) {final _that = this;
switch (_that) {
case _StepSyncResultModel() when $default != null:
return $default(_that.accepted,_that.ignored);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StepSyncResultModel extends StepSyncResultModel {
  const _StepSyncResultModel({required this.accepted, required this.ignored}): super._();
  factory _StepSyncResultModel.fromJson(Map<String, dynamic> json) => _$StepSyncResultModelFromJson(json);

@override final  int accepted;
@override final  int ignored;

/// Create a copy of StepSyncResultModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StepSyncResultModelCopyWith<_StepSyncResultModel> get copyWith => __$StepSyncResultModelCopyWithImpl<_StepSyncResultModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StepSyncResultModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StepSyncResultModel&&(identical(other.accepted, accepted) || other.accepted == accepted)&&(identical(other.ignored, ignored) || other.ignored == ignored));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accepted,ignored);

@override
String toString() {
  return 'StepSyncResultModel(accepted: $accepted, ignored: $ignored)';
}


}

/// @nodoc
abstract mixin class _$StepSyncResultModelCopyWith<$Res> implements $StepSyncResultModelCopyWith<$Res> {
  factory _$StepSyncResultModelCopyWith(_StepSyncResultModel value, $Res Function(_StepSyncResultModel) _then) = __$StepSyncResultModelCopyWithImpl;
@override @useResult
$Res call({
 int accepted, int ignored
});




}
/// @nodoc
class __$StepSyncResultModelCopyWithImpl<$Res>
    implements _$StepSyncResultModelCopyWith<$Res> {
  __$StepSyncResultModelCopyWithImpl(this._self, this._then);

  final _StepSyncResultModel _self;
  final $Res Function(_StepSyncResultModel) _then;

/// Create a copy of StepSyncResultModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accepted = null,Object? ignored = null,}) {
  return _then(_StepSyncResultModel(
accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as int,ignored: null == ignored ? _self.ignored : ignored // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

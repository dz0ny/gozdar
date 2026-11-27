// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'forest_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ForestData {

 List<Parcel> get parcels;/// Sečnja marks per parcel id, for the count on each row.
 Map<int, int> get secnjaCounts;
/// Create a copy of ForestData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ForestDataCopyWith<ForestData> get copyWith => _$ForestDataCopyWithImpl<ForestData>(this as ForestData, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ForestData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ForestData&&const DeepCollectionEquality().equals(other.parcels, _this.parcels)&&const DeepCollectionEquality().equals(other.secnjaCounts, _this.secnjaCounts));
}


@override
int get hashCode {
  final _this = this as ForestData;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.parcels),const DeepCollectionEquality().hash(_this.secnjaCounts));
}

@override
String toString() {
  final _this = this as ForestData;
  return 'ForestData(parcels: ${_this.parcels}, secnjaCounts: ${_this.secnjaCounts})';
}


}

/// @nodoc
abstract mixin class $ForestDataCopyWith<$Res>  {
  factory $ForestDataCopyWith(ForestData value, $Res Function(ForestData) _then) = _$ForestDataCopyWithImpl;
@useResult
$Res call({
 List<Parcel> parcels, Map<int, int> secnjaCounts
});




}
/// @nodoc
class _$ForestDataCopyWithImpl<$Res>
    implements $ForestDataCopyWith<$Res> {
  _$ForestDataCopyWithImpl(this._self, this._then);

  final ForestData _self;
  final $Res Function(ForestData) _then;

/// Create a copy of ForestData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? parcels = null,Object? secnjaCounts = null,}) {
  return _then(ForestData(
parcels: null == parcels ? _self.parcels : parcels // ignore: cast_nullable_to_non_nullable
as List<Parcel>,secnjaCounts: null == secnjaCounts ? _self.secnjaCounts : secnjaCounts // ignore: cast_nullable_to_non_nullable
as Map<int, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [ForestData].
extension ForestDataPatterns on ForestData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ForestData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ForestData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ForestData value)  $default,){
final _that = this;
switch (_that) {
case _ForestData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ForestData value)?  $default,){
final _that = this;
switch (_that) {
case _ForestData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Parcel> parcels,  Map<int, int> secnjaCounts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ForestData() when $default != null:
return $default(_that.parcels,_that.secnjaCounts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Parcel> parcels,  Map<int, int> secnjaCounts)  $default,) {final _that = this;
switch (_that) {
case _ForestData():
return $default(_that.parcels,_that.secnjaCounts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Parcel> parcels,  Map<int, int> secnjaCounts)?  $default,) {final _that = this;
switch (_that) {
case _ForestData() when $default != null:
return $default(_that.parcels,_that.secnjaCounts);case _:
  return null;

}
}

}

/// @nodoc


class _ForestData implements ForestData {
  const _ForestData({ List<Parcel> parcels = const <Parcel>[],  Map<int, int> secnjaCounts = const <int, int>{}}): _parcels = parcels,_secnjaCounts = secnjaCounts;
  

 final  List<Parcel> _parcels;
@override@JsonKey() List<Parcel> get parcels {
  if (_parcels is EqualUnmodifiableListView) return _parcels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parcels);
}

/// Sečnja marks per parcel id, for the count on each row.
 final  Map<int, int> _secnjaCounts;
/// Sečnja marks per parcel id, for the count on each row.
@override@JsonKey() Map<int, int> get secnjaCounts {
  if (_secnjaCounts is EqualUnmodifiableMapView) return _secnjaCounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_secnjaCounts);
}


/// Create a copy of ForestData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ForestDataCopyWith<_ForestData> get copyWith => __$ForestDataCopyWithImpl<_ForestData>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ForestData&&const DeepCollectionEquality().equals(other.parcels, _parcels)&&const DeepCollectionEquality().equals(other.secnjaCounts, _secnjaCounts));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_parcels),const DeepCollectionEquality().hash(_secnjaCounts));
}

@override
String toString() {
    return 'ForestData(parcels: $parcels, secnjaCounts: $secnjaCounts)';
}


}

/// @nodoc
abstract mixin class _$ForestDataCopyWith<$Res> implements $ForestDataCopyWith<$Res> {
  factory _$ForestDataCopyWith(_ForestData value, $Res Function(_ForestData) _then) = __$ForestDataCopyWithImpl;
@override @useResult
$Res call({
 List<Parcel> parcels, Map<int, int> secnjaCounts
});




}
/// @nodoc
class __$ForestDataCopyWithImpl<$Res>
    implements _$ForestDataCopyWith<$Res> {
  __$ForestDataCopyWithImpl(this._self, this._then);

  final _ForestData _self;
  final $Res Function(_ForestData) _then;

/// Create a copy of ForestData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? parcels = null,Object? secnjaCounts = null,}) {
  return _then(_ForestData(
parcels: null == parcels ? _self._parcels : parcels // ignore: cast_nullable_to_non_nullable
as List<Parcel>,secnjaCounts: null == secnjaCounts ? _self._secnjaCounts : secnjaCounts // ignore: cast_nullable_to_non_nullable
as Map<int, int>,
  ));
}


}

// dart format on

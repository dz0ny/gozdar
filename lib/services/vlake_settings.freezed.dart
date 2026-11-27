// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vlake_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VlakeState {

/// Developer unlock: whether the Vlake layer is available at all.
 bool get enabled;/// User toggle (layer selector): whether the layer is shown when available.
 bool get visible;
/// Create a copy of VlakeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VlakeStateCopyWith<VlakeState> get copyWith => _$VlakeStateCopyWithImpl<VlakeState>(this as VlakeState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VlakeState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VlakeState&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.visible, _this.visible) || other.visible == _this.visible));
}


@override
int get hashCode {
  final _this = this as VlakeState;
  return Object.hash(runtimeType,_this.enabled,_this.visible);
}

@override
String toString() {
  final _this = this as VlakeState;
  return 'VlakeState(enabled: ${_this.enabled}, visible: ${_this.visible})';
}


}

/// @nodoc
abstract mixin class $VlakeStateCopyWith<$Res>  {
  factory $VlakeStateCopyWith(VlakeState value, $Res Function(VlakeState) _then) = _$VlakeStateCopyWithImpl;
@useResult
$Res call({
 bool enabled, bool visible
});




}
/// @nodoc
class _$VlakeStateCopyWithImpl<$Res>
    implements $VlakeStateCopyWith<$Res> {
  _$VlakeStateCopyWithImpl(this._self, this._then);

  final VlakeState _self;
  final $Res Function(VlakeState) _then;

/// Create a copy of VlakeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? visible = null,}) {
  return _then(VlakeState(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VlakeState].
extension VlakeStatePatterns on VlakeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VlakeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VlakeState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VlakeState value)  $default,){
final _that = this;
switch (_that) {
case _VlakeState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VlakeState value)?  $default,){
final _that = this;
switch (_that) {
case _VlakeState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  bool visible)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VlakeState() when $default != null:
return $default(_that.enabled,_that.visible);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  bool visible)  $default,) {final _that = this;
switch (_that) {
case _VlakeState():
return $default(_that.enabled,_that.visible);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  bool visible)?  $default,) {final _that = this;
switch (_that) {
case _VlakeState() when $default != null:
return $default(_that.enabled,_that.visible);case _:
  return null;

}
}

}

/// @nodoc


class _VlakeState extends VlakeState {
  const _VlakeState({this.enabled = false, this.visible = true}): super._();
  

/// Developer unlock: whether the Vlake layer is available at all.
@override@JsonKey() final  bool enabled;
/// User toggle (layer selector): whether the layer is shown when available.
@override@JsonKey() final  bool visible;

/// Create a copy of VlakeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VlakeStateCopyWith<_VlakeState> get copyWith => __$VlakeStateCopyWithImpl<_VlakeState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VlakeState&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.visible, visible) || other.visible == visible));
}


@override
int get hashCode {
    return Object.hash(runtimeType,enabled,visible);
}

@override
String toString() {
    return 'VlakeState(enabled: $enabled, visible: $visible)';
}


}

/// @nodoc
abstract mixin class _$VlakeStateCopyWith<$Res> implements $VlakeStateCopyWith<$Res> {
  factory _$VlakeStateCopyWith(_VlakeState value, $Res Function(_VlakeState) _then) = __$VlakeStateCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, bool visible
});




}
/// @nodoc
class __$VlakeStateCopyWithImpl<$Res>
    implements _$VlakeStateCopyWith<$Res> {
  __$VlakeStateCopyWithImpl(this._self, this._then);

  final _VlakeState _self;
  final $Res Function(_VlakeState) _then;

/// Create a copy of VlakeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? visible = null,}) {
  return _then(_VlakeState(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on

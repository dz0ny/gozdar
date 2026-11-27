// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'logs_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConversionFactors {

 double get prm; double get nm;
/// Create a copy of ConversionFactors
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversionFactorsCopyWith<ConversionFactors> get copyWith => _$ConversionFactorsCopyWithImpl<ConversionFactors>(this as ConversionFactors, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ConversionFactors;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversionFactors&&(identical(other.prm, _this.prm) || other.prm == _this.prm)&&(identical(other.nm, _this.nm) || other.nm == _this.nm));
}


@override
int get hashCode {
  final _this = this as ConversionFactors;
  return Object.hash(runtimeType,_this.prm,_this.nm);
}

@override
String toString() {
  final _this = this as ConversionFactors;
  return 'ConversionFactors(prm: ${_this.prm}, nm: ${_this.nm})';
}


}

/// @nodoc
abstract mixin class $ConversionFactorsCopyWith<$Res>  {
  factory $ConversionFactorsCopyWith(ConversionFactors value, $Res Function(ConversionFactors) _then) = _$ConversionFactorsCopyWithImpl;
@useResult
$Res call({
 double prm, double nm
});




}
/// @nodoc
class _$ConversionFactorsCopyWithImpl<$Res>
    implements $ConversionFactorsCopyWith<$Res> {
  _$ConversionFactorsCopyWithImpl(this._self, this._then);

  final ConversionFactors _self;
  final $Res Function(ConversionFactors) _then;

/// Create a copy of ConversionFactors
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? prm = null,Object? nm = null,}) {
  return _then(ConversionFactors(
prm: null == prm ? _self.prm : prm // ignore: cast_nullable_to_non_nullable
as double,nm: null == nm ? _self.nm : nm // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversionFactors].
extension ConversionFactorsPatterns on ConversionFactors {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversionFactors value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversionFactors() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversionFactors value)  $default,){
final _that = this;
switch (_that) {
case _ConversionFactors():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversionFactors value)?  $default,){
final _that = this;
switch (_that) {
case _ConversionFactors() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double prm,  double nm)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversionFactors() when $default != null:
return $default(_that.prm,_that.nm);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double prm,  double nm)  $default,) {final _that = this;
switch (_that) {
case _ConversionFactors():
return $default(_that.prm,_that.nm);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double prm,  double nm)?  $default,) {final _that = this;
switch (_that) {
case _ConversionFactors() when $default != null:
return $default(_that.prm,_that.nm);case _:
  return null;

}
}

}

/// @nodoc


class _ConversionFactors extends ConversionFactors {
  const _ConversionFactors({this.prm = 0.65, this.nm = 0.40}): super._();
  

@override@JsonKey() final  double prm;
@override@JsonKey() final  double nm;

/// Create a copy of ConversionFactors
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversionFactorsCopyWith<_ConversionFactors> get copyWith => __$ConversionFactorsCopyWithImpl<_ConversionFactors>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversionFactors&&(identical(other.prm, prm) || other.prm == prm)&&(identical(other.nm, nm) || other.nm == nm));
}


@override
int get hashCode {
    return Object.hash(runtimeType,prm,nm);
}

@override
String toString() {
    return 'ConversionFactors(prm: $prm, nm: $nm)';
}


}

/// @nodoc
abstract mixin class _$ConversionFactorsCopyWith<$Res> implements $ConversionFactorsCopyWith<$Res> {
  factory _$ConversionFactorsCopyWith(_ConversionFactors value, $Res Function(_ConversionFactors) _then) = __$ConversionFactorsCopyWithImpl;
@override @useResult
$Res call({
 double prm, double nm
});




}
/// @nodoc
class __$ConversionFactorsCopyWithImpl<$Res>
    implements _$ConversionFactorsCopyWith<$Res> {
  __$ConversionFactorsCopyWithImpl(this._self, this._then);

  final _ConversionFactors _self;
  final $Res Function(_ConversionFactors) _then;

/// Create a copy of ConversionFactors
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? prm = null,Object? nm = null,}) {
  return _then(_ConversionFactors(
prm: null == prm ? _self.prm : prm // ignore: cast_nullable_to_non_nullable
as double,nm: null == nm ? _self.nm : nm // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$LogsState {

/// Logs not in any batch.
 List<LogEntry> get logEntries; List<LogBatch> get batches; double get totalVolume; bool get isLoading; bool get isBatchesLoading; String? get error; ConversionFactors get conversionFactors;/// Species assigned to logs added from the Hlodi tab (null = none).
 String? get currentSpecies;/// Id of the log added last from this tab, so the list can scroll to it
/// and mark it. Null until something is added.
 int? get lastAddedId;
/// Create a copy of LogsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LogsStateCopyWith<LogsState> get copyWith => _$LogsStateCopyWithImpl<LogsState>(this as LogsState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LogsState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LogsState&&const DeepCollectionEquality().equals(other.logEntries, _this.logEntries)&&const DeepCollectionEquality().equals(other.batches, _this.batches)&&(identical(other.totalVolume, _this.totalVolume) || other.totalVolume == _this.totalVolume)&&(identical(other.isLoading, _this.isLoading) || other.isLoading == _this.isLoading)&&(identical(other.isBatchesLoading, _this.isBatchesLoading) || other.isBatchesLoading == _this.isBatchesLoading)&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.conversionFactors, _this.conversionFactors) || other.conversionFactors == _this.conversionFactors)&&(identical(other.currentSpecies, _this.currentSpecies) || other.currentSpecies == _this.currentSpecies)&&(identical(other.lastAddedId, _this.lastAddedId) || other.lastAddedId == _this.lastAddedId));
}


@override
int get hashCode {
  final _this = this as LogsState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.logEntries),const DeepCollectionEquality().hash(_this.batches),_this.totalVolume,_this.isLoading,_this.isBatchesLoading,_this.error,_this.conversionFactors,_this.currentSpecies,_this.lastAddedId);
}

@override
String toString() {
  final _this = this as LogsState;
  return 'LogsState(logEntries: ${_this.logEntries}, batches: ${_this.batches}, totalVolume: ${_this.totalVolume}, isLoading: ${_this.isLoading}, isBatchesLoading: ${_this.isBatchesLoading}, error: ${_this.error}, conversionFactors: ${_this.conversionFactors}, currentSpecies: ${_this.currentSpecies}, lastAddedId: ${_this.lastAddedId})';
}


}

/// @nodoc
abstract mixin class $LogsStateCopyWith<$Res>  {
  factory $LogsStateCopyWith(LogsState value, $Res Function(LogsState) _then) = _$LogsStateCopyWithImpl;
@useResult
$Res call({
 List<LogEntry> logEntries, List<LogBatch> batches, double totalVolume, bool isLoading, bool isBatchesLoading, String? error, ConversionFactors conversionFactors, String? currentSpecies, int? lastAddedId
});


$ConversionFactorsCopyWith<$Res> get conversionFactors;

}
/// @nodoc
class _$LogsStateCopyWithImpl<$Res>
    implements $LogsStateCopyWith<$Res> {
  _$LogsStateCopyWithImpl(this._self, this._then);

  final LogsState _self;
  final $Res Function(LogsState) _then;

/// Create a copy of LogsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? logEntries = null,Object? batches = null,Object? totalVolume = null,Object? isLoading = null,Object? isBatchesLoading = null,Object? error = freezed,Object? conversionFactors = null,Object? currentSpecies = freezed,Object? lastAddedId = freezed,}) {
  return _then(LogsState(
logEntries: null == logEntries ? _self.logEntries : logEntries // ignore: cast_nullable_to_non_nullable
as List<LogEntry>,batches: null == batches ? _self.batches : batches // ignore: cast_nullable_to_non_nullable
as List<LogBatch>,totalVolume: null == totalVolume ? _self.totalVolume : totalVolume // ignore: cast_nullable_to_non_nullable
as double,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isBatchesLoading: null == isBatchesLoading ? _self.isBatchesLoading : isBatchesLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,conversionFactors: null == conversionFactors ? _self.conversionFactors : conversionFactors // ignore: cast_nullable_to_non_nullable
as ConversionFactors,currentSpecies: freezed == currentSpecies ? _self.currentSpecies : currentSpecies // ignore: cast_nullable_to_non_nullable
as String?,lastAddedId: freezed == lastAddedId ? _self.lastAddedId : lastAddedId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of LogsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConversionFactorsCopyWith<$Res> get conversionFactors {
  
  return $ConversionFactorsCopyWith<$Res>(_self.conversionFactors, (value) {
    return _then(_self.copyWith(conversionFactors: value));
  });
}
}


/// Adds pattern-matching-related methods to [LogsState].
extension LogsStatePatterns on LogsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LogsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LogsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LogsState value)  $default,){
final _that = this;
switch (_that) {
case _LogsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LogsState value)?  $default,){
final _that = this;
switch (_that) {
case _LogsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LogEntry> logEntries,  List<LogBatch> batches,  double totalVolume,  bool isLoading,  bool isBatchesLoading,  String? error,  ConversionFactors conversionFactors,  String? currentSpecies,  int? lastAddedId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LogsState() when $default != null:
return $default(_that.logEntries,_that.batches,_that.totalVolume,_that.isLoading,_that.isBatchesLoading,_that.error,_that.conversionFactors,_that.currentSpecies,_that.lastAddedId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LogEntry> logEntries,  List<LogBatch> batches,  double totalVolume,  bool isLoading,  bool isBatchesLoading,  String? error,  ConversionFactors conversionFactors,  String? currentSpecies,  int? lastAddedId)  $default,) {final _that = this;
switch (_that) {
case _LogsState():
return $default(_that.logEntries,_that.batches,_that.totalVolume,_that.isLoading,_that.isBatchesLoading,_that.error,_that.conversionFactors,_that.currentSpecies,_that.lastAddedId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LogEntry> logEntries,  List<LogBatch> batches,  double totalVolume,  bool isLoading,  bool isBatchesLoading,  String? error,  ConversionFactors conversionFactors,  String? currentSpecies,  int? lastAddedId)?  $default,) {final _that = this;
switch (_that) {
case _LogsState() when $default != null:
return $default(_that.logEntries,_that.batches,_that.totalVolume,_that.isLoading,_that.isBatchesLoading,_that.error,_that.conversionFactors,_that.currentSpecies,_that.lastAddedId);case _:
  return null;

}
}

}

/// @nodoc


class _LogsState extends LogsState {
  const _LogsState({ List<LogEntry> logEntries = const <LogEntry>[],  List<LogBatch> batches = const <LogBatch>[], this.totalVolume = 0.0, this.isLoading = false, this.isBatchesLoading = false, this.error, this.conversionFactors = const ConversionFactors(), this.currentSpecies, this.lastAddedId}): _logEntries = logEntries,_batches = batches,super._();
  

/// Logs not in any batch.
 final  List<LogEntry> _logEntries;
/// Logs not in any batch.
@override@JsonKey() List<LogEntry> get logEntries {
  if (_logEntries is EqualUnmodifiableListView) return _logEntries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_logEntries);
}

 final  List<LogBatch> _batches;
@override@JsonKey() List<LogBatch> get batches {
  if (_batches is EqualUnmodifiableListView) return _batches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_batches);
}

@override@JsonKey() final  double totalVolume;
@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  bool isBatchesLoading;
@override final  String? error;
@override@JsonKey() final  ConversionFactors conversionFactors;
/// Species assigned to logs added from the Hlodi tab (null = none).
@override final  String? currentSpecies;
/// Id of the log added last from this tab, so the list can scroll to it
/// and mark it. Null until something is added.
@override final  int? lastAddedId;

/// Create a copy of LogsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LogsStateCopyWith<_LogsState> get copyWith => __$LogsStateCopyWithImpl<_LogsState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LogsState&&const DeepCollectionEquality().equals(other.logEntries, _logEntries)&&const DeepCollectionEquality().equals(other.batches, _batches)&&(identical(other.totalVolume, totalVolume) || other.totalVolume == totalVolume)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isBatchesLoading, isBatchesLoading) || other.isBatchesLoading == isBatchesLoading)&&(identical(other.error, error) || other.error == error)&&(identical(other.conversionFactors, conversionFactors) || other.conversionFactors == conversionFactors)&&(identical(other.currentSpecies, currentSpecies) || other.currentSpecies == currentSpecies)&&(identical(other.lastAddedId, lastAddedId) || other.lastAddedId == lastAddedId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_logEntries),const DeepCollectionEquality().hash(_batches),totalVolume,isLoading,isBatchesLoading,error,conversionFactors,currentSpecies,lastAddedId);
}

@override
String toString() {
    return 'LogsState(logEntries: $logEntries, batches: $batches, totalVolume: $totalVolume, isLoading: $isLoading, isBatchesLoading: $isBatchesLoading, error: $error, conversionFactors: $conversionFactors, currentSpecies: $currentSpecies, lastAddedId: $lastAddedId)';
}


}

/// @nodoc
abstract mixin class _$LogsStateCopyWith<$Res> implements $LogsStateCopyWith<$Res> {
  factory _$LogsStateCopyWith(_LogsState value, $Res Function(_LogsState) _then) = __$LogsStateCopyWithImpl;
@override @useResult
$Res call({
 List<LogEntry> logEntries, List<LogBatch> batches, double totalVolume, bool isLoading, bool isBatchesLoading, String? error, ConversionFactors conversionFactors, String? currentSpecies, int? lastAddedId
});


@override $ConversionFactorsCopyWith<$Res> get conversionFactors;

}
/// @nodoc
class __$LogsStateCopyWithImpl<$Res>
    implements _$LogsStateCopyWith<$Res> {
  __$LogsStateCopyWithImpl(this._self, this._then);

  final _LogsState _self;
  final $Res Function(_LogsState) _then;

/// Create a copy of LogsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? logEntries = null,Object? batches = null,Object? totalVolume = null,Object? isLoading = null,Object? isBatchesLoading = null,Object? error = freezed,Object? conversionFactors = null,Object? currentSpecies = freezed,Object? lastAddedId = freezed,}) {
  return _then(_LogsState(
logEntries: null == logEntries ? _self._logEntries : logEntries // ignore: cast_nullable_to_non_nullable
as List<LogEntry>,batches: null == batches ? _self._batches : batches // ignore: cast_nullable_to_non_nullable
as List<LogBatch>,totalVolume: null == totalVolume ? _self.totalVolume : totalVolume // ignore: cast_nullable_to_non_nullable
as double,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isBatchesLoading: null == isBatchesLoading ? _self.isBatchesLoading : isBatchesLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,conversionFactors: null == conversionFactors ? _self.conversionFactors : conversionFactors // ignore: cast_nullable_to_non_nullable
as ConversionFactors,currentSpecies: freezed == currentSpecies ? _self.currentSpecies : currentSpecies // ignore: cast_nullable_to_non_nullable
as String?,lastAddedId: freezed == lastAddedId ? _self.lastAddedId : lastAddedId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of LogsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConversionFactorsCopyWith<$Res> get conversionFactors {
  
  return $ConversionFactorsCopyWith<$Res>(_self.conversionFactors, (value) {
    return _then(_self.copyWith(conversionFactors: value));
  });
}
}

// dart format on

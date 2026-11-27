// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'map_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MapState implements DiagnosticableTreeMixin {

 bool get isPreferencesLoaded; MapLayer get currentBaseLayer; Set<MapLayerType> get activeOverlays; String? get workerUrl; List<MapLocation> get locations; List<Parcel> get parcels; List<LogEntry> get geolocatedLogs; bool get isLoadingLocations; bool get isLoadingParcels; bool get isLoadingLogs; bool get isQueryingParcel; NavigationTarget? get navigationTarget; String? get error;/// Area the map should show next, e.g. a share that just arrived.
 LatLngBounds? get pendingFocus;/// Counts focus requests, so asking for the same area twice still
/// moves the map.
 int get focusRequest;
/// Create a copy of MapState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MapStateCopyWith<MapState> get copyWith => _$MapStateCopyWithImpl<MapState>(this as MapState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as MapState;
  properties
    ..add(DiagnosticsProperty('type', 'MapState'))
    ..add(DiagnosticsProperty('isPreferencesLoaded', _this.isPreferencesLoaded))..add(DiagnosticsProperty('currentBaseLayer', _this.currentBaseLayer))..add(DiagnosticsProperty('activeOverlays', _this.activeOverlays))..add(DiagnosticsProperty('workerUrl', _this.workerUrl))..add(DiagnosticsProperty('locations', _this.locations))..add(DiagnosticsProperty('parcels', _this.parcels))..add(DiagnosticsProperty('geolocatedLogs', _this.geolocatedLogs))..add(DiagnosticsProperty('isLoadingLocations', _this.isLoadingLocations))..add(DiagnosticsProperty('isLoadingParcels', _this.isLoadingParcels))..add(DiagnosticsProperty('isLoadingLogs', _this.isLoadingLogs))..add(DiagnosticsProperty('isQueryingParcel', _this.isQueryingParcel))..add(DiagnosticsProperty('navigationTarget', _this.navigationTarget))..add(DiagnosticsProperty('error', _this.error))..add(DiagnosticsProperty('pendingFocus', _this.pendingFocus))..add(DiagnosticsProperty('focusRequest', _this.focusRequest));
}

@override
bool operator ==(Object other) {
  final _this = this as MapState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MapState&&(identical(other.isPreferencesLoaded, _this.isPreferencesLoaded) || other.isPreferencesLoaded == _this.isPreferencesLoaded)&&(identical(other.currentBaseLayer, _this.currentBaseLayer) || other.currentBaseLayer == _this.currentBaseLayer)&&const DeepCollectionEquality().equals(other.activeOverlays, _this.activeOverlays)&&(identical(other.workerUrl, _this.workerUrl) || other.workerUrl == _this.workerUrl)&&const DeepCollectionEquality().equals(other.locations, _this.locations)&&const DeepCollectionEquality().equals(other.parcels, _this.parcels)&&const DeepCollectionEquality().equals(other.geolocatedLogs, _this.geolocatedLogs)&&(identical(other.isLoadingLocations, _this.isLoadingLocations) || other.isLoadingLocations == _this.isLoadingLocations)&&(identical(other.isLoadingParcels, _this.isLoadingParcels) || other.isLoadingParcels == _this.isLoadingParcels)&&(identical(other.isLoadingLogs, _this.isLoadingLogs) || other.isLoadingLogs == _this.isLoadingLogs)&&(identical(other.isQueryingParcel, _this.isQueryingParcel) || other.isQueryingParcel == _this.isQueryingParcel)&&(identical(other.navigationTarget, _this.navigationTarget) || other.navigationTarget == _this.navigationTarget)&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.pendingFocus, _this.pendingFocus) || other.pendingFocus == _this.pendingFocus)&&(identical(other.focusRequest, _this.focusRequest) || other.focusRequest == _this.focusRequest));
}


@override
int get hashCode {
  final _this = this as MapState;
  return Object.hash(runtimeType,_this.isPreferencesLoaded,_this.currentBaseLayer,const DeepCollectionEquality().hash(_this.activeOverlays),_this.workerUrl,const DeepCollectionEquality().hash(_this.locations),const DeepCollectionEquality().hash(_this.parcels),const DeepCollectionEquality().hash(_this.geolocatedLogs),_this.isLoadingLocations,_this.isLoadingParcels,_this.isLoadingLogs,_this.isQueryingParcel,_this.navigationTarget,_this.error,_this.pendingFocus,_this.focusRequest);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as MapState;
  return 'MapState(isPreferencesLoaded: ${_this.isPreferencesLoaded}, currentBaseLayer: ${_this.currentBaseLayer}, activeOverlays: ${_this.activeOverlays}, workerUrl: ${_this.workerUrl}, locations: ${_this.locations}, parcels: ${_this.parcels}, geolocatedLogs: ${_this.geolocatedLogs}, isLoadingLocations: ${_this.isLoadingLocations}, isLoadingParcels: ${_this.isLoadingParcels}, isLoadingLogs: ${_this.isLoadingLogs}, isQueryingParcel: ${_this.isQueryingParcel}, navigationTarget: ${_this.navigationTarget}, error: ${_this.error}, pendingFocus: ${_this.pendingFocus}, focusRequest: ${_this.focusRequest})';
}


}

/// @nodoc
abstract mixin class $MapStateCopyWith<$Res>  {
  factory $MapStateCopyWith(MapState value, $Res Function(MapState) _then) = _$MapStateCopyWithImpl;
@useResult
$Res call({
 bool isPreferencesLoaded, MapLayer currentBaseLayer, Set<MapLayerType> activeOverlays, String? workerUrl, List<MapLocation> locations, List<Parcel> parcels, List<LogEntry> geolocatedLogs, bool isLoadingLocations, bool isLoadingParcels, bool isLoadingLogs, bool isQueryingParcel, NavigationTarget? navigationTarget, String? error, LatLngBounds? pendingFocus, int focusRequest
});




}
/// @nodoc
class _$MapStateCopyWithImpl<$Res>
    implements $MapStateCopyWith<$Res> {
  _$MapStateCopyWithImpl(this._self, this._then);

  final MapState _self;
  final $Res Function(MapState) _then;

/// Create a copy of MapState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isPreferencesLoaded = null,Object? currentBaseLayer = null,Object? activeOverlays = null,Object? workerUrl = freezed,Object? locations = null,Object? parcels = null,Object? geolocatedLogs = null,Object? isLoadingLocations = null,Object? isLoadingParcels = null,Object? isLoadingLogs = null,Object? isQueryingParcel = null,Object? navigationTarget = freezed,Object? error = freezed,Object? pendingFocus = freezed,Object? focusRequest = null,}) {
  return _then(MapState(
isPreferencesLoaded: null == isPreferencesLoaded ? _self.isPreferencesLoaded : isPreferencesLoaded // ignore: cast_nullable_to_non_nullable
as bool,currentBaseLayer: null == currentBaseLayer ? _self.currentBaseLayer : currentBaseLayer // ignore: cast_nullable_to_non_nullable
as MapLayer,activeOverlays: null == activeOverlays ? _self.activeOverlays : activeOverlays // ignore: cast_nullable_to_non_nullable
as Set<MapLayerType>,workerUrl: freezed == workerUrl ? _self.workerUrl : workerUrl // ignore: cast_nullable_to_non_nullable
as String?,locations: null == locations ? _self.locations : locations // ignore: cast_nullable_to_non_nullable
as List<MapLocation>,parcels: null == parcels ? _self.parcels : parcels // ignore: cast_nullable_to_non_nullable
as List<Parcel>,geolocatedLogs: null == geolocatedLogs ? _self.geolocatedLogs : geolocatedLogs // ignore: cast_nullable_to_non_nullable
as List<LogEntry>,isLoadingLocations: null == isLoadingLocations ? _self.isLoadingLocations : isLoadingLocations // ignore: cast_nullable_to_non_nullable
as bool,isLoadingParcels: null == isLoadingParcels ? _self.isLoadingParcels : isLoadingParcels // ignore: cast_nullable_to_non_nullable
as bool,isLoadingLogs: null == isLoadingLogs ? _self.isLoadingLogs : isLoadingLogs // ignore: cast_nullable_to_non_nullable
as bool,isQueryingParcel: null == isQueryingParcel ? _self.isQueryingParcel : isQueryingParcel // ignore: cast_nullable_to_non_nullable
as bool,navigationTarget: freezed == navigationTarget ? _self.navigationTarget : navigationTarget // ignore: cast_nullable_to_non_nullable
as NavigationTarget?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,pendingFocus: freezed == pendingFocus ? _self.pendingFocus : pendingFocus // ignore: cast_nullable_to_non_nullable
as LatLngBounds?,focusRequest: null == focusRequest ? _self.focusRequest : focusRequest // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MapState].
extension MapStatePatterns on MapState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MapState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MapState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MapState value)  $default,){
final _that = this;
switch (_that) {
case _MapState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MapState value)?  $default,){
final _that = this;
switch (_that) {
case _MapState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isPreferencesLoaded,  MapLayer currentBaseLayer,  Set<MapLayerType> activeOverlays,  String? workerUrl,  List<MapLocation> locations,  List<Parcel> parcels,  List<LogEntry> geolocatedLogs,  bool isLoadingLocations,  bool isLoadingParcels,  bool isLoadingLogs,  bool isQueryingParcel,  NavigationTarget? navigationTarget,  String? error,  LatLngBounds? pendingFocus,  int focusRequest)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MapState() when $default != null:
return $default(_that.isPreferencesLoaded,_that.currentBaseLayer,_that.activeOverlays,_that.workerUrl,_that.locations,_that.parcels,_that.geolocatedLogs,_that.isLoadingLocations,_that.isLoadingParcels,_that.isLoadingLogs,_that.isQueryingParcel,_that.navigationTarget,_that.error,_that.pendingFocus,_that.focusRequest);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isPreferencesLoaded,  MapLayer currentBaseLayer,  Set<MapLayerType> activeOverlays,  String? workerUrl,  List<MapLocation> locations,  List<Parcel> parcels,  List<LogEntry> geolocatedLogs,  bool isLoadingLocations,  bool isLoadingParcels,  bool isLoadingLogs,  bool isQueryingParcel,  NavigationTarget? navigationTarget,  String? error,  LatLngBounds? pendingFocus,  int focusRequest)  $default,) {final _that = this;
switch (_that) {
case _MapState():
return $default(_that.isPreferencesLoaded,_that.currentBaseLayer,_that.activeOverlays,_that.workerUrl,_that.locations,_that.parcels,_that.geolocatedLogs,_that.isLoadingLocations,_that.isLoadingParcels,_that.isLoadingLogs,_that.isQueryingParcel,_that.navigationTarget,_that.error,_that.pendingFocus,_that.focusRequest);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isPreferencesLoaded,  MapLayer currentBaseLayer,  Set<MapLayerType> activeOverlays,  String? workerUrl,  List<MapLocation> locations,  List<Parcel> parcels,  List<LogEntry> geolocatedLogs,  bool isLoadingLocations,  bool isLoadingParcels,  bool isLoadingLogs,  bool isQueryingParcel,  NavigationTarget? navigationTarget,  String? error,  LatLngBounds? pendingFocus,  int focusRequest)?  $default,) {final _that = this;
switch (_that) {
case _MapState() when $default != null:
return $default(_that.isPreferencesLoaded,_that.currentBaseLayer,_that.activeOverlays,_that.workerUrl,_that.locations,_that.parcels,_that.geolocatedLogs,_that.isLoadingLocations,_that.isLoadingParcels,_that.isLoadingLogs,_that.isQueryingParcel,_that.navigationTarget,_that.error,_that.pendingFocus,_that.focusRequest);case _:
  return null;

}
}

}

/// @nodoc


class _MapState extends MapState with DiagnosticableTreeMixin {
  const _MapState({this.isPreferencesLoaded = false, this.currentBaseLayer = MapLayer.esriWorldImagery,  Set<MapLayerType> activeOverlays = const <MapLayerType>{}, this.workerUrl,  List<MapLocation> locations = const <MapLocation>[],  List<Parcel> parcels = const <Parcel>[],  List<LogEntry> geolocatedLogs = const <LogEntry>[], this.isLoadingLocations = false, this.isLoadingParcels = false, this.isLoadingLogs = false, this.isQueryingParcel = false, this.navigationTarget, this.error, this.pendingFocus, this.focusRequest = 0}): _activeOverlays = activeOverlays,_locations = locations,_parcels = parcels,_geolocatedLogs = geolocatedLogs,super._();
  

@override@JsonKey() final  bool isPreferencesLoaded;
@override@JsonKey() final  MapLayer currentBaseLayer;
 final  Set<MapLayerType> _activeOverlays;
@override@JsonKey() Set<MapLayerType> get activeOverlays {
  if (_activeOverlays is EqualUnmodifiableSetView) return _activeOverlays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_activeOverlays);
}

@override final  String? workerUrl;
 final  List<MapLocation> _locations;
@override@JsonKey() List<MapLocation> get locations {
  if (_locations is EqualUnmodifiableListView) return _locations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_locations);
}

 final  List<Parcel> _parcels;
@override@JsonKey() List<Parcel> get parcels {
  if (_parcels is EqualUnmodifiableListView) return _parcels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parcels);
}

 final  List<LogEntry> _geolocatedLogs;
@override@JsonKey() List<LogEntry> get geolocatedLogs {
  if (_geolocatedLogs is EqualUnmodifiableListView) return _geolocatedLogs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_geolocatedLogs);
}

@override@JsonKey() final  bool isLoadingLocations;
@override@JsonKey() final  bool isLoadingParcels;
@override@JsonKey() final  bool isLoadingLogs;
@override@JsonKey() final  bool isQueryingParcel;
@override final  NavigationTarget? navigationTarget;
@override final  String? error;
/// Area the map should show next, e.g. a share that just arrived.
@override final  LatLngBounds? pendingFocus;
/// Counts focus requests, so asking for the same area twice still
/// moves the map.
@override@JsonKey() final  int focusRequest;

/// Create a copy of MapState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MapStateCopyWith<_MapState> get copyWith => __$MapStateCopyWithImpl<_MapState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'MapState'))
    ..add(DiagnosticsProperty('isPreferencesLoaded', isPreferencesLoaded))..add(DiagnosticsProperty('currentBaseLayer', currentBaseLayer))..add(DiagnosticsProperty('activeOverlays', activeOverlays))..add(DiagnosticsProperty('workerUrl', workerUrl))..add(DiagnosticsProperty('locations', locations))..add(DiagnosticsProperty('parcels', parcels))..add(DiagnosticsProperty('geolocatedLogs', geolocatedLogs))..add(DiagnosticsProperty('isLoadingLocations', isLoadingLocations))..add(DiagnosticsProperty('isLoadingParcels', isLoadingParcels))..add(DiagnosticsProperty('isLoadingLogs', isLoadingLogs))..add(DiagnosticsProperty('isQueryingParcel', isQueryingParcel))..add(DiagnosticsProperty('navigationTarget', navigationTarget))..add(DiagnosticsProperty('error', error))..add(DiagnosticsProperty('pendingFocus', pendingFocus))..add(DiagnosticsProperty('focusRequest', focusRequest));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MapState&&(identical(other.isPreferencesLoaded, isPreferencesLoaded) || other.isPreferencesLoaded == isPreferencesLoaded)&&(identical(other.currentBaseLayer, currentBaseLayer) || other.currentBaseLayer == currentBaseLayer)&&const DeepCollectionEquality().equals(other.activeOverlays, _activeOverlays)&&(identical(other.workerUrl, workerUrl) || other.workerUrl == workerUrl)&&const DeepCollectionEquality().equals(other.locations, _locations)&&const DeepCollectionEquality().equals(other.parcels, _parcels)&&const DeepCollectionEquality().equals(other.geolocatedLogs, _geolocatedLogs)&&(identical(other.isLoadingLocations, isLoadingLocations) || other.isLoadingLocations == isLoadingLocations)&&(identical(other.isLoadingParcels, isLoadingParcels) || other.isLoadingParcels == isLoadingParcels)&&(identical(other.isLoadingLogs, isLoadingLogs) || other.isLoadingLogs == isLoadingLogs)&&(identical(other.isQueryingParcel, isQueryingParcel) || other.isQueryingParcel == isQueryingParcel)&&(identical(other.navigationTarget, navigationTarget) || other.navigationTarget == navigationTarget)&&(identical(other.error, error) || other.error == error)&&(identical(other.pendingFocus, pendingFocus) || other.pendingFocus == pendingFocus)&&(identical(other.focusRequest, focusRequest) || other.focusRequest == focusRequest));
}


@override
int get hashCode {
    return Object.hash(runtimeType,isPreferencesLoaded,currentBaseLayer,const DeepCollectionEquality().hash(_activeOverlays),workerUrl,const DeepCollectionEquality().hash(_locations),const DeepCollectionEquality().hash(_parcels),const DeepCollectionEquality().hash(_geolocatedLogs),isLoadingLocations,isLoadingParcels,isLoadingLogs,isQueryingParcel,navigationTarget,error,pendingFocus,focusRequest);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'MapState(isPreferencesLoaded: $isPreferencesLoaded, currentBaseLayer: $currentBaseLayer, activeOverlays: $activeOverlays, workerUrl: $workerUrl, locations: $locations, parcels: $parcels, geolocatedLogs: $geolocatedLogs, isLoadingLocations: $isLoadingLocations, isLoadingParcels: $isLoadingParcels, isLoadingLogs: $isLoadingLogs, isQueryingParcel: $isQueryingParcel, navigationTarget: $navigationTarget, error: $error, pendingFocus: $pendingFocus, focusRequest: $focusRequest)';
}


}

/// @nodoc
abstract mixin class _$MapStateCopyWith<$Res> implements $MapStateCopyWith<$Res> {
  factory _$MapStateCopyWith(_MapState value, $Res Function(_MapState) _then) = __$MapStateCopyWithImpl;
@override @useResult
$Res call({
 bool isPreferencesLoaded, MapLayer currentBaseLayer, Set<MapLayerType> activeOverlays, String? workerUrl, List<MapLocation> locations, List<Parcel> parcels, List<LogEntry> geolocatedLogs, bool isLoadingLocations, bool isLoadingParcels, bool isLoadingLogs, bool isQueryingParcel, NavigationTarget? navigationTarget, String? error, LatLngBounds? pendingFocus, int focusRequest
});




}
/// @nodoc
class __$MapStateCopyWithImpl<$Res>
    implements _$MapStateCopyWith<$Res> {
  __$MapStateCopyWithImpl(this._self, this._then);

  final _MapState _self;
  final $Res Function(_MapState) _then;

/// Create a copy of MapState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isPreferencesLoaded = null,Object? currentBaseLayer = null,Object? activeOverlays = null,Object? workerUrl = freezed,Object? locations = null,Object? parcels = null,Object? geolocatedLogs = null,Object? isLoadingLocations = null,Object? isLoadingParcels = null,Object? isLoadingLogs = null,Object? isQueryingParcel = null,Object? navigationTarget = freezed,Object? error = freezed,Object? pendingFocus = freezed,Object? focusRequest = null,}) {
  return _then(_MapState(
isPreferencesLoaded: null == isPreferencesLoaded ? _self.isPreferencesLoaded : isPreferencesLoaded // ignore: cast_nullable_to_non_nullable
as bool,currentBaseLayer: null == currentBaseLayer ? _self.currentBaseLayer : currentBaseLayer // ignore: cast_nullable_to_non_nullable
as MapLayer,activeOverlays: null == activeOverlays ? _self._activeOverlays : activeOverlays // ignore: cast_nullable_to_non_nullable
as Set<MapLayerType>,workerUrl: freezed == workerUrl ? _self.workerUrl : workerUrl // ignore: cast_nullable_to_non_nullable
as String?,locations: null == locations ? _self._locations : locations // ignore: cast_nullable_to_non_nullable
as List<MapLocation>,parcels: null == parcels ? _self._parcels : parcels // ignore: cast_nullable_to_non_nullable
as List<Parcel>,geolocatedLogs: null == geolocatedLogs ? _self._geolocatedLogs : geolocatedLogs // ignore: cast_nullable_to_non_nullable
as List<LogEntry>,isLoadingLocations: null == isLoadingLocations ? _self.isLoadingLocations : isLoadingLocations // ignore: cast_nullable_to_non_nullable
as bool,isLoadingParcels: null == isLoadingParcels ? _self.isLoadingParcels : isLoadingParcels // ignore: cast_nullable_to_non_nullable
as bool,isLoadingLogs: null == isLoadingLogs ? _self.isLoadingLogs : isLoadingLogs // ignore: cast_nullable_to_non_nullable
as bool,isQueryingParcel: null == isQueryingParcel ? _self.isQueryingParcel : isQueryingParcel // ignore: cast_nullable_to_non_nullable
as bool,navigationTarget: freezed == navigationTarget ? _self.navigationTarget : navigationTarget // ignore: cast_nullable_to_non_nullable
as NavigationTarget?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,pendingFocus: freezed == pendingFocus ? _self.pendingFocus : pendingFocus // ignore: cast_nullable_to_non_nullable
as LatLngBounds?,focusRequest: null == focusRequest ? _self.focusRequest : focusRequest // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';
import '../models/map_location.dart';
import '../models/map_layer.dart';
import '../models/parcel.dart';
import '../models/log_entry.dart';
import '../models/navigation_target.dart';
import '../models/secnja_share.dart';
import '../services/cadastral_service.dart';
import '../services/hr_owner_service.dart';
import '../services/ko_locator.dart';
import '../services/parcel_lookup_service.dart';
import 'service_providers.dart';

part 'map_provider.freezed.dart';

/// What the map shows: layers, saved data and the current target.
///
/// The camera position is not here: it changes on every pan and nothing
/// should rebuild for it. [MapNotifier] keeps it.
@freezed
abstract class MapState with _$MapState {
  const MapState._();

  const factory MapState({
    @Default(false) bool isPreferencesLoaded,
    @Default(MapLayer.esriWorldImagery) MapLayer currentBaseLayer,
    @Default(<MapLayerType>{}) Set<MapLayerType> activeOverlays,
    String? workerUrl,
    @Default(<MapLocation>[]) List<MapLocation> locations,
    @Default(<Parcel>[]) List<Parcel> parcels,
    @Default(<LogEntry>[]) List<LogEntry> geolocatedLogs,
    @Default(false) bool isLoadingLocations,
    @Default(false) bool isLoadingParcels,
    @Default(false) bool isLoadingLogs,
    @Default(false) bool isQueryingParcel,
    NavigationTarget? navigationTarget,
    String? error,

    /// Area the map should show next, e.g. a share that just arrived.
    LatLngBounds? pendingFocus,

    /// Counts focus requests, so asking for the same area twice still
    /// moves the map.
    @Default(0) int focusRequest,
  }) = _MapState;

  bool get isSlovenianBase => currentBaseLayer.isSlovenian;
  bool get hasNavigationTarget => navigationTarget != null;
}

/// Map state. The getters read the current state, so a callback that keeps
/// the notifier sees fresh values after an await.
class MapNotifier extends Notifier<MapState> {
  // Camera position: saved on every move, read when the map opens.
  LatLng _center = const LatLng(46.0569, 14.5058);
  double _zoom = 13.0;
  double _rotation = 0.0;

  // The focus request already handed out by [takePendingFocus], so the map
  // moves only once without writing state while a widget builds.
  int _takenFocusRequest = 0;

  // Database watches. Once a load* call starts one, every write to that
  // table (from any screen) reaches the map without a manual reload.
  StreamSubscription<List<MapLocation>>? _locationsSub;
  StreamSubscription<List<Parcel>>? _parcelsSub;
  StreamSubscription<List<LogEntry>>? _logsSub;

  @override
  MapState build() {
    ref.onDispose(() {
      unawaited(_locationsSub?.cancel());
      unawaited(_parcelsSub?.cancel());
      unawaited(_logsSub?.cancel());
    });
    // Loads run after build; state can't be written while it builds.
    Future.microtask(() async {
      await loadPreferences();
      if (!ref.mounted) return;
      await Future.wait([loadLocations(), loadParcels(), loadGeolocatedLogs()]);
    });
    return const MapState();
  }

  // Getters - Position
  LatLng get center => _center;
  double get zoom => _zoom;
  double get rotation => _rotation;
  bool get isPreferencesLoaded => state.isPreferencesLoaded;

  // Getters - Layers
  MapLayer get currentBaseLayer => state.currentBaseLayer;
  Set<MapLayerType> get activeOverlays => state.activeOverlays;
  bool get isSlovenianBase => state.isSlovenianBase;
  String? get workerUrl => state.workerUrl;

  // Getters - Data
  List<MapLocation> get locations => state.locations;
  List<Parcel> get parcels => state.parcels;
  List<LogEntry> get geolocatedLogs => state.geolocatedLogs;
  bool get isLoadingLocations => state.isLoadingLocations;
  bool get isLoadingParcels => state.isLoadingParcels;
  bool get isLoadingLogs => state.isLoadingLogs;
  bool get isQueryingParcel => state.isQueryingParcel;

  // Getters - Navigation
  NavigationTarget? get navigationTarget => state.navigationTarget;
  bool get hasNavigationTarget => state.hasNavigationTarget;

  // Getters - Error
  String? get error => state.error;

  /// Load map preferences from storage
  Future<void> loadPreferences() async {
    try {
      final saved = await ref.read(mapPreferencesServiceProvider).loadAll();
      if (!ref.mounted) return;

      // Find the base layer from saved type
      MapLayer baseLayer = MapLayer.esriWorldImagery;
      for (final layer in MapLayer.baseLayers) {
        if (layer.type == saved.baseLayer) {
          baseLayer = layer;
          break;
        }
      }

      _center = LatLng(saved.latitude, saved.longitude);
      _zoom = saved.zoom;
      _rotation = saved.rotation;
      state = state.copyWith(
        currentBaseLayer: baseLayer,
        activeOverlays: {...saved.overlays},
        workerUrl: saved.workerUrl,
        isPreferencesLoaded: true,
      );
    } catch (e) {
      if (!ref.mounted) return;
      // Use defaults
      state = state.copyWith(error: e.toString(), isPreferencesLoaded: true);
    }
  }

  /// Save current map state to preferences. Doesn't notify: the camera is
  /// already where it was saved.
  Future<void> saveMapState({
    required LatLng center,
    required double zoom,
    required double rotation,
  }) async {
    _center = center;
    _zoom = zoom;
    _rotation = rotation;
    await _savePreferences();
  }

  /// Switch base layer
  void setBaseLayer(MapLayer layer) {
    state = state.copyWith(currentBaseLayer: layer);
    unawaited(_savePreferences());
  }

  /// Toggle an overlay layer
  void toggleOverlay(MapLayerType type) {
    setOverlayActive(type, !state.activeOverlays.contains(type));
  }

  /// Set overlay active state
  void setOverlayActive(MapLayerType type, bool active) {
    final overlays = {...state.activeOverlays};
    if (active) {
      overlays.add(type);
    } else {
      overlays.remove(type);
    }
    state = state.copyWith(activeOverlays: overlays);
    unawaited(_savePreferences());
  }

  Future<void> _savePreferences() async {
    await ref
        .read(mapPreferencesServiceProvider)
        .saveAll(
          latitude: _center.latitude,
          longitude: _center.longitude,
          zoom: _zoom,
          rotation: _rotation,
          baseLayer: state.currentBaseLayer.type,
          overlays: state.activeOverlays,
          workerUrl: state.workerUrl,
        );
  }

  /// Set worker URL
  Future<void> setWorkerUrl(String? url) async {
    state = state.copyWith(workerUrl: url);
    await _savePreferences();
  }

  // Location operations

  /// Asks the map to show [payload]: its parcel, or its trees without one.
  void focusOn(SecnjaSharePayload payload) {
    final points = payload.polygon.isNotEmpty
        ? payload.polygon
        : [for (final p in payload.points) p.position];
    if (points.isEmpty) return;
    state = state.copyWith(
      pendingFocus: LatLngBounds.fromPoints(points),
      focusRequest: state.focusRequest + 1,
    );
  }

  /// Returns the area to show once, so the map moves only once. Safe to
  /// call from a build: it writes no state.
  LatLngBounds? takePendingFocus() {
    final focus = state.pendingFocus;
    if (focus == null || state.focusRequest == _takenFocusRequest) return null;
    _takenFocusRequest = state.focusRequest;
    return focus;
  }

  /// Load all saved locations from database
  Future<void> loadLocations() async {
    if (!ref.mounted) return;
    final db = ref.read(databaseServiceProvider);
    _locationsSub ??= db.watchAllLocations().listen((rows) {
      state = state.copyWith(locations: rows);
    }, onError: _onWatchError);
    state = state.copyWith(isLoadingLocations: true);

    try {
      final locations = await db.getAllLocations();
      if (!ref.mounted) return;
      state = state.copyWith(locations: locations, isLoadingLocations: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingLocations: false, error: e.toString());
    }
  }

  /// Add a new location
  Future<bool> addLocation(MapLocation location) async {
    try {
      await ref.read(databaseServiceProvider).insertLocation(location);
      await loadLocations();
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Delete a location
  Future<bool> deleteLocation(int locationId) async {
    try {
      await ref.read(databaseServiceProvider).deleteLocation(locationId);
      await loadLocations();
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Log operations

  /// Load all geolocated logs from database (logs with latitude/longitude)
  Future<void> loadGeolocatedLogs() async {
    if (!ref.mounted) return;
    final db = ref.read(databaseServiceProvider);
    _logsSub ??= db.watchAllLogs().listen((rows) {
      state = state.copyWith(
        geolocatedLogs: rows.where((log) => log.hasLocation).toList(),
      );
    }, onError: _onWatchError);
    state = state.copyWith(isLoadingLogs: true);

    try {
      final allLogs = await db.getAllLogs();
      if (!ref.mounted) return;
      state = state.copyWith(
        geolocatedLogs: allLogs.where((log) => log.hasLocation).toList(),
        isLoadingLogs: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingLogs: false, error: e.toString());
    }
  }

  // Parcel operations

  /// Load all saved parcels from database
  Future<void> loadParcels() async {
    if (!ref.mounted) return;
    final db = ref.read(databaseServiceProvider);
    _parcelsSub ??= db.watchAllParcels().listen((rows) {
      state = state.copyWith(parcels: rows);
    }, onError: _onWatchError);
    state = state.copyWith(isLoadingParcels: true);

    try {
      final parcels = await db.getAllParcels();
      if (!ref.mounted) return;
      state = state.copyWith(parcels: parcels, isLoadingParcels: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingParcels: false, error: e.toString());
    }
  }

  /// Query cadastral parcel at location.
  ///
  /// When an offline parcels database is loaded, resolve from it directly — no
  /// online proxy/WFS call. Falls back to the online service only when offline
  /// data is unavailable (or the point isn't covered by the local dataset).
  Future<CadastralParcel?> queryParcelAtLocation(LatLng location) async {
    if (state.isQueryingParcel) return null;

    final offline = ParcelLookupService.instance;
    if (offline.isAvailable) {
      final local = offline.parcelAt(location);
      if (local != null) return local;
    }

    state = state.copyWith(isQueryingParcel: true);

    try {
      final parcel = await ref
          .read(cadastralServiceProvider)
          .queryParcelAtLocation(location);
      if (ref.mounted) state = state.copyWith(isQueryingParcel: false);
      return parcel;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isQueryingParcel: false, error: e.toString());
      }
      return null;
    }
  }

  /// Check if cadastral parcel already exists
  Future<bool> cadastralParcelExists(int municipality, String parcelNumber) {
    return ref
        .read(databaseServiceProvider)
        .cadastralParcelExists(municipality, parcelNumber);
  }

  /// Import a cadastral parcel
  Future<bool> importCadastralParcel(CadastralParcel cadastralParcel) async {
    try {
      // Check if parcel already exists
      final exists = await cadastralParcelExists(
        cadastralParcel.cadastralMunicipality,
        cadastralParcel.parcelNumber,
      );

      if (exists) {
        if (ref.mounted) {
          state = state.copyWith(
            error: L10n.current.mapwParcelAlreadyInDb(
              cadastralParcel.cadastralMunicipality.toString(),
              cadastralParcel.parcelNumber.toString(),
            ),
          );
        }
        return false;
      }

      // Croatian holders are only fetched live, so keep them with the parcel.
      final ko = cadastralParcel.cadastralMunicipality;
      final hrOwner = HrOwnerService.isCroatianKo(ko)
          ? await HrOwnerService.instance.lookup(
              ko,
              cadastralParcel.parcelNumber,
              parcelId: cadastralParcel.id,
            )
          : null;

      final parcel = Parcel(
        name: await KoLocator.defaultParcelName(
          cadastralParcel.cadastralMunicipality,
          cadastralParcel.parcelNumber,
        ),
        polygon: cadastralParcel.polygon,
        cadastralMunicipality: cadastralParcel.cadastralMunicipality,
        parcelNumber: cadastralParcel.parcelNumber,
        owner: hrOwner?.displayOwners,
      );

      await ref.read(databaseServiceProvider).insertParcel(parcel);
      await loadParcels();
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Navigation operations

  /// Set navigation target
  void setNavigationTarget(NavigationTarget target) {
    state = state.copyWith(navigationTarget: target);
  }

  /// Clear navigation target
  void clearNavigationTarget() {
    state = state.copyWith(navigationTarget: null);
  }

  void _onWatchError(Object e, StackTrace s) {
    debugPrint('MapNotifier watch failed: $e\n$s');
    if (ref.mounted) state = state.copyWith(error: e.toString());
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final mapNotifierProvider = NotifierProvider<MapNotifier, MapState>(
  MapNotifier.new,
);

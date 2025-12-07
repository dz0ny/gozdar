import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_location.dart';
import '../models/map_layer.dart';
import '../models/parcel.dart';
import '../models/log_entry.dart';
import '../models/navigation_target.dart';
import '../services/database_service.dart';
import '../services/map_preferences_service.dart';
import '../services/cadastral_service.dart';

/// Provider for map state management
class MapProvider extends ChangeNotifier {
  final DatabaseService _databaseService;
  final MapPreferencesService _prefsService;
  final CadastralService _cadastralService;

  MapProvider({
    DatabaseService? databaseService,
    MapPreferencesService? prefsService,
    CadastralService? cadastralService,
  }) : _databaseService = databaseService ?? DatabaseService(),
       _prefsService = prefsService ?? MapPreferencesService(),
       _cadastralService = cadastralService ?? CadastralService();

  // Map position state
  LatLng _center = const LatLng(46.0569, 14.5058);
  double _zoom = 13.0;
  double _rotation = 0.0;
  bool _isPreferencesLoaded = false;

  // Layer state
  MapLayer _currentBaseLayer = MapLayer.esriWorldImagery;
  final Set<MapLayerType> _activeOverlays = {};
  String? _workerUrl;
  bool _isDebugInfoVisible = false;

  // Data state
  List<MapLocation> _locations = [];
  List<Parcel> _parcels = [];
  List<LogEntry> _geolocatedLogs = [];
  bool _isLoadingLocations = false;
  bool _isLoadingParcels = false;
  bool _isLoadingLogs = false;
  bool _isQueryingParcel = false;

  // Navigation state
  NavigationTarget? _navigationTarget;

  // Error state
  String? _error;

  // Getters - Position
  LatLng get center => _center;
  double get zoom => _zoom;
  double get rotation => _rotation;
  bool get isPreferencesLoaded => _isPreferencesLoaded;

  // Getters - Layers
  MapLayer get currentBaseLayer => _currentBaseLayer;
  Set<MapLayerType> get activeOverlays => Set.unmodifiable(_activeOverlays);
  bool get isSlovenianBase => _currentBaseLayer.isSlovenian;
  String? get workerUrl => _workerUrl;
  bool get isDebugInfoVisible => _isDebugInfoVisible;

  // Getters - Data
  List<MapLocation> get locations => List.unmodifiable(_locations);
  List<Parcel> get parcels => List.unmodifiable(_parcels);
  List<LogEntry> get geolocatedLogs => List.unmodifiable(_geolocatedLogs);
  bool get isLoadingLocations => _isLoadingLocations;
  bool get isLoadingParcels => _isLoadingParcels;
  bool get isLoadingLogs => _isLoadingLogs;
  bool get isQueryingParcel => _isQueryingParcel;

  // Getters - Navigation
  NavigationTarget? get navigationTarget => _navigationTarget;
  bool get hasNavigationTarget => _navigationTarget != null;

  // Getters - Error
  String? get error => _error;

  /// Load map preferences from storage
  Future<void> loadPreferences() async {
    try {
      final state = await _prefsService.loadAll();

      // Find the base layer from saved type
      MapLayer baseLayer = MapLayer.esriWorldImagery;
      for (final layer in MapLayer.baseLayers) {
        if (layer.type == state.baseLayer) {
          baseLayer = layer;
          break;
        }
      }

      _center = LatLng(state.latitude, state.longitude);
      _zoom = state.zoom;
      _rotation = state.rotation;
      _currentBaseLayer = baseLayer;
      _activeOverlays.clear();
      _activeOverlays.addAll(state.overlays);
      _workerUrl = state.workerUrl;
      _isPreferencesLoaded = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isPreferencesLoaded = true; // Use defaults
      notifyListeners();
    }
  }

  /// Save current map state to preferences
  Future<void> saveMapState({
    required LatLng center,
    required double zoom,
    required double rotation,
  }) async {
    _center = center;
    _zoom = zoom;
    _rotation = rotation;

    await _prefsService.saveAll(
      latitude: center.latitude,
      longitude: center.longitude,
      zoom: zoom,
      rotation: rotation,
      baseLayer: _currentBaseLayer.type,
      overlays: _activeOverlays,
      workerUrl: _workerUrl,
    );
  }

  /// Switch base layer
  void setBaseLayer(MapLayer layer) {
    _currentBaseLayer = layer;
    notifyListeners();
    _saveLayerPreferences();
  }

  /// Toggle an overlay layer
  void toggleOverlay(MapLayerType type) {
    if (_activeOverlays.contains(type)) {
      _activeOverlays.remove(type);
    } else {
      _activeOverlays.add(type);
    }
    notifyListeners();
    _saveLayerPreferences();
  }

  /// Set overlay active state
  void setOverlayActive(MapLayerType type, bool active) {
    if (active) {
      _activeOverlays.add(type);
    } else {
      _activeOverlays.remove(type);
    }
    notifyListeners();
    _saveLayerPreferences();
  }

  Future<void> _saveLayerPreferences() async {
    await _prefsService.saveAll(
      latitude: _center.latitude,
      longitude: _center.longitude,
      zoom: _zoom,
      rotation: _rotation,
      baseLayer: _currentBaseLayer.type,
      overlays: _activeOverlays,
      workerUrl: _workerUrl,
    );
  }

  /// Set worker URL
  Future<void> setWorkerUrl(String? url) async {
    _workerUrl = url;
    notifyListeners();
    await _saveLayerPreferences();
  }

  /// Set debug info visibility
  void setDebugInfoVisible(bool visible) {
    _isDebugInfoVisible = visible;
    notifyListeners();
  }

  // Location operations

  /// Load all saved locations from database
  Future<void> loadLocations() async {
    _isLoadingLocations = true;
    notifyListeners();

    try {
      final locations = await _databaseService.getAllLocations();
      _locations = locations;
      _isLoadingLocations = false;
      notifyListeners();
    } catch (e) {
      _isLoadingLocations = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a new location
  Future<bool> addLocation(MapLocation location) async {
    try {
      await _databaseService.insertLocation(location);
      await loadLocations();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a location
  Future<bool> deleteLocation(int locationId) async {
    try {
      await _databaseService.deleteLocation(locationId);
      await loadLocations();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Log operations

  /// Load all geolocated logs from database (logs with latitude/longitude)
  Future<void> loadGeolocatedLogs() async {
    _isLoadingLogs = true;
    notifyListeners();

    try {
      final allLogs = await _databaseService.getAllLogs();
      _geolocatedLogs = allLogs.where((log) => log.hasLocation).toList();
      _isLoadingLogs = false;
      notifyListeners();
    } catch (e) {
      _isLoadingLogs = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  // Parcel operations

  /// Load all saved parcels from database
  Future<void> loadParcels() async {
    _isLoadingParcels = true;
    notifyListeners();

    try {
      final parcels = await _databaseService.getAllParcels();
      _parcels = parcels;
      _isLoadingParcels = false;
      notifyListeners();
    } catch (e) {
      _isLoadingParcels = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Query cadastral parcel at location
  Future<CadastralParcel?> queryParcelAtLocation(LatLng location) async {
    if (_isQueryingParcel) return null;

    _isQueryingParcel = true;
    notifyListeners();

    try {
      final parcel = await _cadastralService.queryParcelAtLocation(location);
      _isQueryingParcel = false;
      notifyListeners();
      return parcel;
    } catch (e) {
      _isQueryingParcel = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Check if cadastral parcel already exists
  Future<bool> cadastralParcelExists(
    int municipality,
    String parcelNumber,
  ) async {
    return await _databaseService.cadastralParcelExists(
      municipality,
      parcelNumber,
    );
  }

  /// Import a cadastral parcel
  Future<bool> importCadastralParcel(CadastralParcel cadastralParcel) async {
    try {
      final parcel = Parcel(
        name:
            'Parcela ${cadastralParcel.parcelNumber} (KO ${cadastralParcel.cadastralMunicipality})',
        polygon: cadastralParcel.polygon,
        cadastralMunicipality: cadastralParcel.cadastralMunicipality,
        parcelNumber: cadastralParcel.parcelNumber,
      );

      await _databaseService.insertParcel(parcel);
      await loadParcels();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Navigation operations

  /// Set navigation target
  void setNavigationTarget(NavigationTarget target) {
    _navigationTarget = target;
    notifyListeners();
  }

  /// Clear navigation target
  void clearNavigationTarget() {
    _navigationTarget = null;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

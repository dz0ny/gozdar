import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_layer.dart';
import '../models/map_location.dart';
import '../models/parcel.dart';
import '../models/log_entry.dart';
import '../models/navigation_target.dart';
import '../services/map_preferences_service.dart';

/// Manages the state of the map including position, layers, and data
class MapStateManager {
  // Map controller for programmatic map control
  final MapController _mapController = MapController();
  final MapPreferencesService _prefsService = MapPreferencesService();

  // Initial map state (loaded from preferences)
  LatLng _initialCenter = const LatLng(46.0569, 14.5058);
  double _initialZoom = 13.0;
  double _initialRotation = 0.0;

  // Current map state
  MapLayer _currentBaseLayer = MapLayer.openStreetMap;
  final Set<MapLayerType> _activeOverlays = {};
  List<MapLocation> _locations = [];
  List<Parcel> _parcels = [];
  List<LogEntry> _geolocatedLogs = [];
  bool _isLoadingLocations = false;
  bool _isLoadingPreferences = true;

  // Navigation target
  NavigationTarget? _navigationTarget;

  // Current zoom level for dynamic marker sizing
  double _currentZoom = 13.0;

  // Getters
  MapController get mapController => _mapController;
  LatLng get initialCenter => _initialCenter;
  double get initialZoom => _initialZoom;
  double get initialRotation => _initialRotation;
  MapLayer get currentBaseLayer => _currentBaseLayer;
  Set<MapLayerType> get activeOverlays => _activeOverlays;
  List<MapLocation> get locations => _locations;
  List<Parcel> get parcels => _parcels;
  List<LogEntry> get geolocatedLogs => _geolocatedLogs;
  bool get isLoadingLocations => _isLoadingLocations;
  bool get isLoadingPreferences => _isLoadingPreferences;
  NavigationTarget? get navigationTarget => _navigationTarget;
  double get currentZoom => _currentZoom;

  /// Load map preferences from storage
  Future<void> loadPreferences() async {
    try {
      final state = await _prefsService.loadAll();

      MapLayer baseLayer = MapLayer.openStreetMap;
      for (final layer in MapLayer.baseLayers) {
        if (layer.type == state.baseLayer) {
          baseLayer = layer;
          break;
        }
      }

      _initialCenter = LatLng(state.latitude, state.longitude);
      _initialZoom = state.zoom;
      _currentZoom = state.zoom;
      _initialRotation = state.rotation;
      _currentBaseLayer = baseLayer;
      _activeOverlays.clear();
      _activeOverlays.addAll(state.overlays);
      _isLoadingPreferences = false;
    } catch (e) {
      debugPrint('Error loading map preferences: $e');
      _isLoadingPreferences = false;
    }
  }

  /// Save current map state to preferences
  Future<void> saveMapState() async {
    final camera = _mapController.camera;
    await _prefsService.saveAll(
      latitude: camera.center.latitude,
      longitude: camera.center.longitude,
      zoom: camera.zoom,
      rotation: camera.rotation,
      baseLayer: _currentBaseLayer.type,
      overlays: _activeOverlays,
    );
  }

  /// Update current zoom level
  void updateZoom(double zoom) {
    _currentZoom = zoom;
  }

  /// Set navigation target
  void setNavigationTarget(NavigationTarget target) {
    _navigationTarget = target;
  }

  /// Clear navigation target
  void clearNavigationTarget() {
    _navigationTarget = null;
  }

  /// Switch base layer
  void switchBaseLayer(MapLayer newLayer) {
    _currentBaseLayer = newLayer;
  }

  /// Toggle overlay layer
  void toggleOverlay(MapLayerType overlayType) {
    if (_activeOverlays.contains(overlayType)) {
      _activeOverlays.remove(overlayType);
    } else {
      _activeOverlays.add(overlayType);
    }
  }

  /// Update locations
  void updateLocations(List<MapLocation> locations) {
    _locations = locations;
    _isLoadingLocations = false;
  }

  /// Update parcels
  void updateParcels(List<Parcel> parcels) {
    _parcels = parcels;
  }

  /// Update geolocated logs
  void updateGeolocatedLogs(List<LogEntry> logs) {
    _geolocatedLogs = logs;
  }

  /// Set navigation target
  set navigationTarget(NavigationTarget? target) {
    _navigationTarget = target;
  }

  /// Update current zoom
  set currentZoom(double zoom) {
    _currentZoom = zoom;
  }

  /// Dispose of resources
  void dispose() {
    _mapController.dispose();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../models/map_layer.dart';
import '../models/map_location.dart';
import '../models/parcel.dart';
import '../models/log_entry.dart';
import '../models/navigation_target.dart';
import '../services/map_preferences_service.dart';

/// Manages the state of the map including position, layers, and user location
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

  // User location tracking
  Position? _userPosition;
  double? _userHeading;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

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
  Position? get userPosition => _userPosition;
  double? get userHeading => _userHeading;
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

  /// Initialize location tracking
  Future<void> initializeLocationTracking() async {
    // Check location permission first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied');
      return;
    }

    // Get initial position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _userPosition = position;
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }

    // Start location updates
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // Update every 5 meters
          ),
        ).listen(
          (Position position) {
            _userPosition = position;
          },
          onError: (error) {
            debugPrint('Location stream error: $error');
          },
        );

    // Start compass updates
    _compassSubscription = FlutterCompass.events?.listen(
      (CompassEvent event) {
        _userHeading = event.heading;
      },
      onError: (error) {
        debugPrint('Compass error: $error');
      },
    );
  }

  /// Dispose of resources
  void dispose() {
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController.dispose();
  }
}

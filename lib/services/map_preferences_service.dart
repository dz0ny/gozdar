import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_layer.dart';

/// Service to persist map state (position, zoom, rotation, layers)
class MapPreferencesService {
  static const String _keyLatitude = 'map_latitude';
  static const String _keyLongitude = 'map_longitude';
  static const String _keyZoom = 'map_zoom';
  static const String _keyRotation = 'map_rotation';
  static const String _keyBaseLayer = 'map_base_layer';
  static const String _keyOverlays = 'map_overlays';
  static const String _keyWorkerUrl = 'map_worker_url';

  // Default proxy URL
  static const String defaultWorkerUrl = 'https://gozdar-proxy.dz0ny.workers.dev';

  // Default values (Ljubljana, Slovenia)
  static const double defaultLatitude = 46.0569;
  static const double defaultLongitude = 14.5058;
  static const double defaultZoom = 13.0;
  static const double defaultRotation = 0.0;

  /// Save map position
  Future<void> savePosition(double latitude, double longitude) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLatitude, latitude);
    await prefs.setDouble(_keyLongitude, longitude);
  }

  /// Save map zoom level
  Future<void> saveZoom(double zoom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyZoom, zoom);
  }

  /// Save map rotation
  Future<void> saveRotation(double rotation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyRotation, rotation);
  }

  /// Save base layer type
  Future<void> saveBaseLayer(MapLayerType layerType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseLayer, layerType.name);
  }

  /// Save enabled overlay layers
  Future<void> saveOverlays(Set<MapLayerType> overlays) async {
    final prefs = await SharedPreferences.getInstance();
    final overlayNames = overlays.map((e) => e.name).toList();
    await prefs.setStringList(_keyOverlays, overlayNames);
  }

  /// Save worker URL
  Future<void> saveWorkerUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove(_keyWorkerUrl);
    } else {
      await prefs.setString(_keyWorkerUrl, url);
    }
  }

  /// Save all map state at once
  Future<void> saveAll({
    required double latitude,
    required double longitude,
    required double zoom,
    required double rotation,
    required MapLayerType baseLayer,
    required Set<MapLayerType> overlays,
    String? workerUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLatitude, latitude);
    await prefs.setDouble(_keyLongitude, longitude);
    await prefs.setDouble(_keyZoom, zoom);
    await prefs.setDouble(_keyRotation, rotation);
    await prefs.setString(_keyBaseLayer, baseLayer.name);
    await prefs.setStringList(
      _keyOverlays,
      overlays.map((e) => e.name).toList(),
    );

    if (workerUrl == null || workerUrl.isEmpty) {
      await prefs.remove(_keyWorkerUrl);
    } else {
      await prefs.setString(_keyWorkerUrl, workerUrl);
    }
  }

  /// Load saved latitude
  Future<double> getLatitude() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyLatitude) ?? defaultLatitude;
  }

  /// Load saved longitude
  Future<double> getLongitude() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyLongitude) ?? defaultLongitude;
  }

  /// Load saved zoom level
  Future<double> getZoom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyZoom) ?? defaultZoom;
  }

  /// Load saved rotation
  Future<double> getRotation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyRotation) ?? defaultRotation;
  }

  /// Load saved base layer type
  Future<MapLayerType> getBaseLayer() async {
    final prefs = await SharedPreferences.getInstance();
    final layerName = prefs.getString(_keyBaseLayer);
    // Default to ESRI for fresh installs
    if (layerName == null) return MapLayerType.esriWorldImagery;

    try {
      return MapLayerType.values.firstWhere((e) => e.name == layerName);
    } catch (_) {
      return MapLayerType.esriWorldImagery;
    }
  }

  /// Load saved overlay layers
  Future<Set<MapLayerType>> getOverlays() async {
    final prefs = await SharedPreferences.getInstance();
    // Check if overlays key exists - if not, it's a fresh install
    if (!prefs.containsKey(_keyOverlays)) {
      // Default overlays for fresh install: Kataster and Kataster z nazivi
      return {MapLayerType.kataster, MapLayerType.katasterNazivi};
    }

    final overlayNames = prefs.getStringList(_keyOverlays) ?? [];

    final overlays = <MapLayerType>{};
    for (final name in overlayNames) {
      try {
        final type = MapLayerType.values.firstWhere((e) => e.name == name);
        overlays.add(type);
      } catch (_) {
        // Skip invalid overlay names
      }
    }
    return overlays;
  }

  /// Load saved worker URL
  Future<String> getWorkerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWorkerUrl) ?? defaultWorkerUrl;
  }

  /// Load all map state at once
  Future<MapState> loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    final latitude = prefs.getDouble(_keyLatitude) ?? defaultLatitude;
    final longitude = prefs.getDouble(_keyLongitude) ?? defaultLongitude;
    final zoom = prefs.getDouble(_keyZoom) ?? defaultZoom;
    final rotation = prefs.getDouble(_keyRotation) ?? defaultRotation;

    // Default to ESRI for fresh installs
    final layerName = prefs.getString(_keyBaseLayer);
    MapLayerType baseLayer = MapLayerType.esriWorldImagery;
    if (layerName != null) {
      try {
        baseLayer = MapLayerType.values.firstWhere((e) => e.name == layerName);
      } catch (_) {}
    }

    // Default overlays for fresh install: Kataster and Kataster z nazivi
    Set<MapLayerType> overlays;
    if (!prefs.containsKey(_keyOverlays)) {
      overlays = {MapLayerType.kataster, MapLayerType.katasterNazivi};
    } else {
      final overlayNames = prefs.getStringList(_keyOverlays) ?? [];
      overlays = <MapLayerType>{};
      for (final name in overlayNames) {
        try {
          final type = MapLayerType.values.firstWhere((e) => e.name == name);
          overlays.add(type);
        } catch (_) {}
      }
    }

    final workerUrl = prefs.getString(_keyWorkerUrl) ?? defaultWorkerUrl;

    return MapState(
      latitude: latitude,
      longitude: longitude,
      zoom: zoom,
      rotation: rotation,
      baseLayer: baseLayer,
      overlays: overlays,
      workerUrl: workerUrl,
    );
  }
}

/// Represents saved map state
class MapState {
  final double latitude;
  final double longitude;
  final double zoom;
  final double rotation;
  final MapLayerType baseLayer;
  final Set<MapLayerType> overlays;
  final String workerUrl;

  const MapState({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.rotation,
    required this.baseLayer,
    required this.overlays,
    required this.workerUrl,
  });
}

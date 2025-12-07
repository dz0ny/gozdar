import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';
import '../models/map_location.dart';
import '../models/map_layer.dart';
import '../models/parcel.dart';
import '../models/navigation_target.dart';
import '../models/log_entry.dart';
import '../utils/slovenian_crs.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../widgets/log_entry_form.dart';
import '../services/map_preferences_service.dart';
import '../services/cadastral_service.dart';
import '../services/tile_cache_service.dart';
import '../widgets/location_pointer.dart';
import '../widgets/navigation_compass_dialog.dart';
import '../widgets/tile_download_dialog.dart';
import '../widgets/map_long_press_menu.dart';
import '../widgets/navigation_target_banner.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_layer_selector.dart';
import '../widgets/map_dialogs.dart';
import '../widgets/saved_locations_sheet.dart';
import '../providers/map_provider.dart';

/// Map Tab screen for the Gozdar app
/// Displays an interactive map with support for multiple layers,
/// saved locations, and GPS functionality
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => MapTabState();
}

class MapTabState extends State<MapTab> {
  // Map controller for programmatic map control
  final MapController _mapController = MapController();
  final MapPreferencesService _prefsService = MapPreferencesService();
  final TileCacheService _tileCacheService = TileCacheService();

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
  bool _isQueryingParcel = false;
  bool _isLoadingPreferences =
      true; // Wait for preferences before rendering map

  // User location tracking
  Position? _userPosition;
  double? _userHeading;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // Navigation target (set from ParcelDetailScreen)
  NavigationTarget? _navigationTarget;

  // Long press menu state
  Offset? _longPressScreenPosition;
  LatLng? _longPressMapPosition;

  // Current zoom level for dynamic marker sizing
  double _currentZoom = 13.0;

  /// Check if markers should be visible at current zoom
  /// Slovenian CRS has different zoom scale, so lower threshold needed
  bool get _showMarkers {
    // Check if proxy is active - if so, we use standard Web Mercator
    // Note: We use read() here because watch() is called in build()
    // or this getter is called during build where watch() has already registered
    final workerUrl = context.read<MapProvider>().workerUrl;

    if (_currentBaseLayer.isWms && workerUrl == null) {
      return _currentZoom >= 11; // Slovenian CRS
    }
    return _currentZoom >= 15; // Standard Web Mercator
  }

  /// Calculate marker size based on zoom level
  /// Returns smaller sizes at lower zoom levels
  double _getMarkerSize(double baseSize) {
    final workerUrl = context.read<MapProvider>().workerUrl;

    if (_currentBaseLayer.isWms && workerUrl == null) {
      // Slovenian CRS: scale 0.4-1.0 for zoom 11-15
      final scale = ((_currentZoom - 11) / 4).clamp(0.4, 1.0);
      return baseSize * scale;
    }
    // Standard Web Mercator: scale 0.5-1.0 for zoom 15-17
    final scale = ((_currentZoom - 15) / 2).clamp(0.5, 1.0);
    return baseSize * scale;
  }

  /// Set navigation target and center map on it
  void setNavigationTarget(NavigationTarget target, {bool zoomIn = true}) {
    // Update provider state
    context.read<MapProvider>().setNavigationTarget(target);
    AnalyticsService().logNavigationStarted();

    setState(() {
      _navigationTarget = target;
    });
    // Center map on target location
    final currentRotation = _mapController.camera.rotation;
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = zoomIn
        ? 17.0.clamp(7.0, _currentBaseLayer.maxZoom)
        : currentZoom;
    _mapController.moveAndRotate(target.location, targetZoom, currentRotation);
  }

  /// Clear navigation target
  void clearNavigationTarget() {
    context.read<MapProvider>().clearNavigationTarget();
    setState(() {
      _navigationTarget = null;
    });
  }

  /// Show compass dialog for navigation target
  void _showCompassForTarget() {
    if (_navigationTarget == null) return;
    AnalyticsService().logCompassOpened();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: NavigationCompassDialog(
          targetLocation: _navigationTarget!.location,
          targetName: _navigationTarget!.name,
        ),
      ),
    );
  }

  /// Show tile download dialog (triggered by triple-tap on Karta tab)
  void showTileDownloadDialog() {
    final bounds = _mapController.camera.visibleBounds;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: TileDownloadDialog(
          currentLayer: _currentBaseLayer,
          bounds: bounds,
          currentZoom: _currentZoom.toInt(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadLocations();
    _loadParcels();
    _loadGeolocatedLogs();
    _initializeLocationTracking();
  }

  /// Load saved map preferences
  Future<void> _loadPreferences() async {
    final state = await _prefsService.loadAll();

    // Find the base layer from saved type
    MapLayer baseLayer = MapLayer.openStreetMap;
    for (final layer in MapLayer.baseLayers) {
      if (layer.type == state.baseLayer) {
        baseLayer = layer;
        break;
      }
    }

    setState(() {
      _initialCenter = LatLng(state.latitude, state.longitude);
      _initialZoom = state.zoom;
      _currentZoom = state.zoom;
      _initialRotation = state.rotation;
      _currentBaseLayer = baseLayer;
      _activeOverlays.clear();
      _activeOverlays.addAll(state.overlays);
      _isLoadingPreferences = false;
    });
  }

  /// Save current map state to preferences
  Future<void> _saveMapState() async {
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

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Load saved locations from database
  Future<void> _loadLocations() async {
    setState(() {
      _isLoadingLocations = true;
    });

    try {
      final locations = await DatabaseService().getAllLocations();

      setState(() {
        _locations = locations;
        _isLoadingLocations = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLocations = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri nalaganju lokacij: $e')),
        );
      }
    }
  }

  /// Load saved parcels from database
  Future<void> _loadParcels() async {
    try {
      final parcels = await DatabaseService().getAllParcels();
      if (mounted) {
        setState(() {
          _parcels = parcels;
        });
      }
    } catch (e) {
      debugPrint('Error loading parcels: $e');
    }
  }

  /// Load geolocated logs from database
  Future<void> _loadGeolocatedLogs() async {
    try {
      final allLogs = await DatabaseService().getAllLogs();
      final logsWithLocation = allLogs.where((log) => log.hasLocation).toList();
      if (mounted) {
        setState(() {
          _geolocatedLogs = logsWithLocation;
        });
      }
    } catch (e) {
      debugPrint('Error loading geolocated logs: $e');
    }
  }

  /// Initialize real-time location and compass tracking
  Future<void> _initializeLocationTracking() async {
    // Check location permission first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    }

    // Subscribe to compass updates for heading
    final compassStream = FlutterCompass.events;
    if (compassStream != null) {
      _compassSubscription = compassStream.listen((event) {
        if (mounted && event.heading != null) {
          setState(() {
            _userHeading = event.heading;
          });
        }
      });
    }

    // Subscribe to position updates
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // Update every 5 meters
          ),
        ).listen(
          (position) {
            if (mounted) {
              setState(() {
                _userPosition = position;
                // Use GPS heading as fallback if compass is unavailable
                if (_userHeading == null && position.heading >= 0) {
                  _userHeading = position.heading;
                }
              });
            }
          },
          onError: (error) {
            debugPrint('Position stream error: $error');
          },
        );

    // Get initial position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _userPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }
  }

  /// Center map on user's current GPS location
  Future<void> _centerOnGpsLocation() async {
    try {
      // Check location service status
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lokacijske storitve so onemogočene')),
          );
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dovoljenje za lokacijo zavrnjeno')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dovoljenje za lokacijo trajno zavrnjeno'),
            ),
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Animate map to current location (respect maxZoom), reset rotation to north
      final targetZoom = 15.0.clamp(7.0, _currentBaseLayer.maxZoom);
      _mapController.moveAndRotate(
        LatLng(position.latitude, position.longitude),
        targetZoom,
        0, // Reset rotation to north
      );
      AnalyticsService().logGpsCentered();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri pridobivanju lokacije: $e')),
        );
      }
    }
  }

  /// Show dialog to add a new location
  Future<void> _showAddLocationDialog(LatLng position) async {
    final name = await MapDialogs.showAddLocationDialog(
      context: context,
      position: position,
    );

    if (name != null) {
      await _addLocation(name, position.latitude, position.longitude);
    }
  }

  /// Add a new location to the database
  Future<void> _addLocation(String name, double lat, double lng) async {
    try {
      final location = MapLocation(name: name, latitude: lat, longitude: lng);

      // Use provider for the operation
      final success = await context.read<MapProvider>().addLocation(location);
      if (success) {
        await _loadLocations(); // Sync local state
        AnalyticsService().logLocationAdded();
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Dodano "$name"')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Napaka: ${context.read<MapProvider>().error}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri dodajanju lokacije: $e')),
        );
      }
    }
  }

  /// Show dialog to add sečnja marker (tree to be cut)
  Future<void> _showAddSecnjaDialog(LatLng position) async {
    final name = await MapDialogs.showAddSecnjaDialog(
      context: context,
      position: position,
    );

    if (name != null) {
      await _addSecnja(name, position.latitude, position.longitude);
    }
  }

  /// Add a sečnja marker to the database
  Future<void> _addSecnja(String name, double lat, double lng) async {
    try {
      final location = MapLocation(
        name: name,
        latitude: lat,
        longitude: lng,
        type: LocationType.secnja,
      );

      // Use provider for the operation
      final success = await context.read<MapProvider>().addLocation(location);
      if (success) {
        await _loadLocations(); // Sync local state
        AnalyticsService().logSecnjaAdded();
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Sečnja "$name" označena')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Napaka: ${context.read<MapProvider>().error}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri označevanju sečnje: $e')),
        );
      }
    }
  }

  /// Show log entry form with pre-filled location
  Future<void> _showAddLogDialog(LatLng position) async {
    // Create a partial log entry with just the location
    final prefilledEntry = LogEntry(
      volume: 0,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    final result = await Navigator.of(context).push<LogEntry>(
      MaterialPageRoute(
        builder: (context) => LogEntryForm(logEntry: prefilledEntry),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      try {
        await DatabaseService().insertLog(result);
        await _loadGeolocatedLogs(); // Refresh log markers
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Hlod dodan (${result.volume.toStringAsFixed(3)} m³)',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka pri dodajanju hloda: $e')),
          );
        }
      }
    }
  }

  /// Show dialog to confirm location deletion
  Future<void> _showDeleteLocationDialog(MapLocation location) async {
    final confirmed = await MapDialogs.showDeleteLocationDialog(
      context: context,
      location: location,
    );

    if (confirmed) {
      await _deleteLocation(location);
    }
  }

  /// Delete a location from the database
  Future<void> _deleteLocation(MapLocation location) async {
    try {
      if (location.id != 0) {
        // Use provider for the operation
        final success = await context.read<MapProvider>().deleteLocation(
          location.id,
        );
        if (success) {
          await _loadLocations(); // Sync local state
          AnalyticsService().logLocationDeleted();
        }

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Izbrisano "${location.name}"')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Napaka: ${context.read<MapProvider>().error}'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri brisanju lokacije: $e')),
        );
      }
    }
  }

  /// Query cadastral parcel at the given location and show import dialog
  Future<void> _queryParcelAtLocation(LatLng location) async {
    if (_isQueryingParcel) return;

    setState(() {
      _isQueryingParcel = true;
    });

    try {
      // Use provider for the query
      final parcel = await context.read<MapProvider>().queryParcelAtLocation(
        location,
      );

      if (!mounted) return;

      setState(() {
        _isQueryingParcel = false;
      });

      if (parcel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Na tej lokaciji ni najdene parcele')),
        );
        return;
      }

      // Show import dialog
      await _showImportParcelDialog(parcel);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isQueryingParcel = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri iskanju parcele: $e')),
        );
      }
    }
  }

  /// Show dialog to import a cadastral parcel
  Future<void> _showImportParcelDialog(CadastralParcel cadastralParcel) async {
    // Check if parcel already exists using provider
    final mapProvider = context.read<MapProvider>();
    final exists = await mapProvider.cadastralParcelExists(
      cadastralParcel.cadastralMunicipality,
      cadastralParcel.parcelNumber,
    );

    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Parcela ${cadastralParcel.parcelNumber} (KO ${cadastralParcel.cadastralMunicipality}) je ze uvozena',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    final confirmed = await MapDialogs.showImportParcelDialog(
      context: context,
      cadastralParcel: cadastralParcel,
    );

    if (confirmed) {
      await _importCadastralParcel(cadastralParcel);
    }
  }

  /// Import a cadastral parcel into the database
  Future<void> _importCadastralParcel(CadastralParcel cadastralParcel) async {
    try {
      // Use provider for the import
      final success = await context.read<MapProvider>().importCadastralParcel(
        cadastralParcel,
      );

      if (success) {
        // Reload parcels to show the new one on the map
        await _loadParcels();
        AnalyticsService().logParcelImportedCadastral();

        // Download tiles for offline use in the background
        _downloadTilesForParcel(cadastralParcel.polygon);
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Parcela ${cadastralParcel.parcelNumber} uspesno uvozena',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Napaka: ${context.read<MapProvider>().error}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Napaka pri uvozu parcele: $e')));
      }
    }
  }

  /// Download tiles for a parcel's bounding box in the background
  void _downloadTilesForParcel(List<LatLng> polygon) {
    if (polygon.isEmpty) return;

    // Calculate bounding box from polygon with some padding
    double minLat = polygon.first.latitude;
    double maxLat = polygon.first.latitude;
    double minLng = polygon.first.longitude;
    double maxLng = polygon.first.longitude;

    for (final point in polygon) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add ~100m padding around the parcel
    const padding = 0.001; // ~100m in degrees
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    // Start background download (fire-and-forget)
    _tileCacheService.downloadForParcelBounds(bounds);
  }

  /// Switch base layer while preserving current position
  void _switchBaseLayer(MapLayer newLayer) {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;

    // Clamp zoom to new layer's max zoom
    final newZoom = currentZoom.clamp(7.0, newLayer.maxZoom);

    setState(() {
      _currentBaseLayer = newLayer;
    });

    // Track layer change
    AnalyticsService().logMapLayerChanged(layerName: newLayer.type.name);

    // Move to same position with adjusted zoom if needed, preserving rotation
    if (newZoom != currentZoom) {
      final currentRotation = _mapController.camera.rotation;
      Future.microtask(() {
        if (mounted) {
          _mapController.moveAndRotate(currentCenter, newZoom, currentRotation);
        }
      });
    }

    // Save layer preference
    _saveMapState();
  }

  /// Show layer selection bottom sheet
  Future<void> _showLayerSelector() async {
    await MapLayerSelector.show(
      context: context,
      currentBaseLayer: _currentBaseLayer,
      activeOverlays: _activeOverlays,
      workerUrl: context.read<MapProvider>().workerUrl,
      onBaseLayerChanged: (layer) {
        _switchBaseLayer(layer);
      },
      onOverlayToggled: (type) {
        final wasEnabled = _activeOverlays.contains(type);
        setState(() {
          if (wasEnabled) {
            _activeOverlays.remove(type);
          } else {
            _activeOverlays.add(type);
          }
        });
        AnalyticsService().logMapOverlayToggled(
          overlayName: type.name,
          enabled: !wasEnabled,
        );
        _saveMapState();
      },
    );
  }

  /// Build tile layer for a specific layer
  /// All layers are cached for up to 1 year
  Widget _buildTileLayerForLayer(MapLayer layer) {
    // Check for worker URL
    final workerUrl = context.read<MapProvider>().workerUrl;

    // If worker URL is set and layer is Slovenian/WMS, use the proxy
    if (workerUrl != null && (layer.isSlovenian || layer.isWms)) {
      // Convert enum name to kebab-case slug
      // e.g. katasterNazivi -> kataster-nazivi, vetrolom2017 -> vetrolom-2017
      final slug = layer.type.name
          .replaceAllMapped(
            RegExp(r'(?<!^)(?=[A-Z])|(?<=[a-z])(?=[0-9])'),
            (match) => '-',
          )
          .toLowerCase();

      return TileLayer(
        urlTemplate: '$workerUrl/tiles/$slug/{z}/{x}/{y}',
        maxZoom: layer.maxZoom,
        minZoom: layer.minZoom,
        userAgentPackageName: 'dev.dz0ny.gozdar',
        tileProvider: _tileCacheService
            .getGeneralTileProvider(), // Enable local cache
      );
    }

    if (layer.isWms) {
      // Use Slovenian cache for prostor.zgs.gov.si WMS layers
      final isSlovenian = layer.isSlovenian;

      return TileLayer(
        wmsOptions: WMSTileLayerOptions(
          baseUrl: layer.wmsBaseUrl!,
          layers: layer.wmsLayers!,
          styles: layer.wmsStyles != null ? [layer.wmsStyles!] : const [''],
          format: layer.wmsFormat ?? 'image/jpeg',
          transparent: layer.isTransparent,
          crs: slovenianCrs,
        ),
        tileProvider: isSlovenian
            ? _tileCacheService.getTileProvider()
            : _tileCacheService.getGeneralTileProvider(),
        userAgentPackageName: 'dev.dz0ny.gozdar',
        maxZoom: layer.maxZoom,
        minZoom: layer.minZoom,
      );
    } else {
      // Use general cache for standard tile layers (OSM, ESRI, Google, etc.)
      return TileLayer(
        urlTemplate: layer.urlTemplate!,
        maxZoom: layer.maxZoom,
        minZoom: layer.minZoom,
        tileProvider: _tileCacheService.getGeneralTileProvider(),
        userAgentPackageName: 'dev.dz0ny.gozdar',
      );
    }
  }

  /// Build list of overlay tile layers
  /// Slovenian overlays (from prostor.zgs.gov.si) only render when base layer is also Slovenian
  /// OR when using proxy (which handles projection)
  List<Widget> _buildOverlayLayers() {
    final isSlovenianBase = _currentBaseLayer.isSlovenian;
    final workerUrl = context.read<MapProvider>().workerUrl;

    return MapLayer.overlayLayers
        .where((layer) => _activeOverlays.contains(layer.type))
        .where(
          (layer) => !layer.isSlovenian || isSlovenianBase || workerUrl != null,
        )
        .map((layer) => _buildTileLayerForLayer(layer))
        .toList();
  }

  /// Build markers for saved locations (excluding sečnja)
  List<Marker> _buildMarkers() {
    final size = _getMarkerSize(36);
    final iconSize = _getMarkerSize(18);
    final borderWidth = _getMarkerSize(2.5);
    // Filter out sečnja markers - they have their own layer
    return _locations.where((loc) => !loc.isSecnja).map((location) {
      final point = LatLng(location.latitude, location.longitude);
      return Marker(
        point: point,
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () {
            // Set as navigation target
            setNavigationTarget(
              NavigationTarget(location: point, name: location.name),
              zoomIn: false,
            );
          },
          onLongPress: () => _showDeleteLocationDialog(location),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.location_on,
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Build markers for geolocated logs (hlodovina)
  List<Marker> _buildLogMarkers() {
    final size = _getMarkerSize(32);
    final iconSize = _getMarkerSize(16);
    final borderWidth = _getMarkerSize(2);
    return _geolocatedLogs.map((log) {
      final point = LatLng(log.latitude!, log.longitude!);
      return Marker(
        point: point,
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () {
            // Set as navigation target
            setNavigationTarget(
              NavigationTarget(
                location: point,
                name: '${log.volume.toStringAsFixed(2)} m³',
              ),
              zoomIn: false,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.brown,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.forest, size: iconSize, color: Colors.white),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Build markers for sečnja (trees to be cut)
  List<Marker> _buildSecnjaMarkers() {
    final size = _getMarkerSize(34);
    final iconSize = _getMarkerSize(17);
    final borderWidth = _getMarkerSize(2);
    // Filter only sečnja markers
    return _locations.where((loc) => loc.isSecnja).map((location) {
      final point = LatLng(location.latitude, location.longitude);
      return Marker(
        point: point,
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () {
            // Set as navigation target
            setNavigationTarget(
              NavigationTarget(location: point, name: location.name),
              zoomIn: false,
            );
          },
          onLongPress: () => _showDeleteLocationDialog(location),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.deepOrange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.carpenter, size: iconSize, color: Colors.white),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Build markers for parcel vertices (mejne tocke)
  List<Marker> _buildParcelVertexMarkers() {
    final size = _getMarkerSize(28);
    final fontSize = _getMarkerSize(12);
    final borderWidth = _getMarkerSize(2);
    final markers = <Marker>[];
    for (final parcel in _parcels) {
      for (int i = 0; i < parcel.polygon.length; i++) {
        final point = parcel.polygon[i];
        final pointName = parcel.getPointName(i);
        markers.add(
          Marker(
            point: point,
            width: size,
            height: size,
            child: GestureDetector(
              onTap: () {
                // Set as navigation target (don't zoom, just move)
                setNavigationTarget(
                  NavigationTarget(
                    location: point,
                    name: '$pointName (${parcel.name})',
                  ),
                  zoomIn: false,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider for changes (including worker URL, parcels, locations)
    final mapProvider = context.watch<MapProvider>();

    // Sync parcels from provider when they change
    if (mapProvider.parcels.length != _parcels.length ||
        (mapProvider.parcels.isNotEmpty &&
            _parcels.isNotEmpty &&
            mapProvider.parcels.first.id != _parcels.first.id)) {
      // Schedule sync after build to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _parcels = List.from(mapProvider.parcels);
          });
        }
      });
    }

    // Sync geolocated logs from provider when they change
    if (mapProvider.geolocatedLogs.length != _geolocatedLogs.length ||
        (mapProvider.geolocatedLogs.isNotEmpty &&
            _geolocatedLogs.isNotEmpty &&
            mapProvider.geolocatedLogs.first.id != _geolocatedLogs.first.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _geolocatedLogs = List.from(mapProvider.geolocatedLogs);
          });
        }
      });
    }

    // Sync locations from provider when they change
    if (mapProvider.locations.length != _locations.length ||
        (mapProvider.locations.isNotEmpty &&
            _locations.isNotEmpty &&
            mapProvider.locations.first.id != _locations.first.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _locations = List.from(mapProvider.locations);
          });
        }
      });
    }

    // Show loading indicator while preferences are loading
    if (_isLoadingPreferences) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Nalagam karto...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map widget
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Use Slovenian CRS for WMS layers (EPSG:3794), otherwise default Web Mercator
              // If proxy is active (workerUrl != null), always use Web Mercator (EPSG:3857)
              crs:
                  (_currentBaseLayer.isWms &&
                      context.read<MapProvider>().workerUrl == null)
                  ? slovenianCrs
                  : const Epsg3857(),
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              initialRotation: _initialRotation,
              minZoom: 7.0,
              maxZoom: _currentBaseLayer.maxZoom,
              // Move to saved position when map is ready
              onMapReady: () {
                _mapController.moveAndRotate(
                  _initialCenter,
                  _initialZoom,
                  _initialRotation,
                );
              },
              // Handle tap to dismiss long press menu
              onTap: (tapPosition, point) {
                if (_longPressScreenPosition != null) {
                  setState(() {
                    _longPressScreenPosition = null;
                    _longPressMapPosition = null;
                  });
                }
              },
              // Handle long press to show action menu
              onLongPress: (tapPosition, point) {
                setState(() {
                  _longPressScreenPosition = tapPosition.global;
                  _longPressMapPosition = point;
                });
              },
              // Save map state when position/zoom/rotation changes
              onMapEvent: (event) {
                if (event is MapEventMoveEnd || event is MapEventRotateEnd) {
                  _saveMapState();
                }
                // Track zoom level for dynamic marker sizing
                if (event.camera.zoom != _currentZoom) {
                  setState(() {
                    _currentZoom = event.camera.zoom;
                  });
                }
                // Dismiss menu on map move
                if (event is MapEventMoveStart &&
                    _longPressScreenPosition != null) {
                  setState(() {
                    _longPressScreenPosition = null;
                    _longPressMapPosition = null;
                  });
                }
              },
            ),
            children: [
              _buildTileLayerForLayer(_currentBaseLayer),
              // Overlay layers
              ..._buildOverlayLayers(),
              // Saved parcels as polygons
              if (_parcels.isNotEmpty)
                PolygonLayer(
                  polygons: _parcels
                      .map(
                        (parcel) => Polygon(
                          points: parcel.polygon,
                          color: Colors.green.withValues(alpha: 0.2),
                          borderColor: Colors.green,
                          borderStrokeWidth: 2.0,
                          label: parcel.name,
                          labelStyle: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ),
              // Parcel vertex markers (mejne tocke) - hidden at low zoom
              if (_parcels.isNotEmpty && _showMarkers)
                MarkerLayer(markers: _buildParcelVertexMarkers()),
              // User location marker
              if (_userPosition != null)
                Builder(
                  builder: (context) {
                    final userSize = _getMarkerSize(30);
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                          ),
                          width: userSize,
                          height: userSize,
                          child: LocationPointer(
                            heading: _userHeading,
                            color: Theme.of(context).colorScheme.primary,
                            size: userSize,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              // Saved locations marker layer - always visible
              MarkerLayer(markers: _buildMarkers()),
              // Geolocated logs marker layer - always visible
              MarkerLayer(markers: _buildLogMarkers()),
              // Sečnja markers layer - always visible
              MarkerLayer(markers: _buildSecnjaMarkers()),
              // Navigation target line (from user to target)
              if (_navigationTarget != null && _userPosition != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(
                          _userPosition!.latitude,
                          _userPosition!.longitude,
                        ),
                        _navigationTarget!.location,
                      ],
                      color: Colors.orange.withValues(alpha: 0.6),
                      strokeWidth: 3,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
              // Navigation target marker
              if (_navigationTarget != null)
                Builder(
                  builder: (context) {
                    final navSize = _getMarkerSize(50);
                    final navIconSize = _getMarkerSize(28);
                    final navBorderWidth = _getMarkerSize(3);
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: _navigationTarget!.location,
                          width: navSize,
                          height: navSize,
                          child: GestureDetector(
                            onTap: _showCompassForTarget,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: navBorderWidth,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.navigation,
                                color: Colors.white,
                                size: navIconSize,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),

          // Navigation target info banner
          if (_navigationTarget != null)
            NavigationTargetBanner(
              target: _navigationTarget!,
              onTap: _showCompassForTarget,
              onClose: clearNavigationTarget,
            ),

          // Debug info overlay
          if (context.watch<MapProvider>().isDebugInfoVisible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zoom: ${_currentZoom.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      'Center: ${_mapController.camera.center.latitude.toStringAsFixed(4)}, ${_mapController.camera.center.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      'Rotation: ${_mapController.camera.rotation.toStringAsFixed(1)}°',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator for locations
          if (_isLoadingLocations)
            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                  (_navigationTarget != null ? 90 : 16) +
                  (context.watch<MapProvider>().isDebugInfoVisible ? 80 : 0),
              left: 16,
              child: const Material(
                elevation: 4,
                borderRadius: BorderRadius.all(Radius.circular(8)),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Loading indicator for parcel query
          if (_isQueryingParcel)
            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                  (_navigationTarget != null ? 90 : 16),
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 4,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Iskanje parcele...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Long press action menu
          if (_longPressScreenPosition != null && _longPressMapPosition != null)
            Builder(
              builder: (context) {
                // Capture position at build time so it persists after onDismiss clears state
                final position = _longPressMapPosition!;
                return MapLongPressMenu(
                  screenPosition: _longPressScreenPosition!,
                  mapPosition: position,
                  onAddLocation: () => _showAddLocationDialog(position),
                  onAddLog: () => _showAddLogDialog(position),
                  onAddSecnja: () => _showAddSecnjaDialog(position),
                  onImportParcel: () => _queryParcelAtLocation(position),
                  onDismiss: () => setState(() {
                    _longPressScreenPosition = null;
                    _longPressMapPosition = null;
                  }),
                );
              },
            ),

          // Attribution overlay (bottom left) - tap to see usage rights
          Positioned(
            bottom: 4,
            left: 4,
            child: GestureDetector(
              onTap: _showUsageRightsDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      _buildAttributionText(),
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Zoom and layer controls at top, GPS at bottom
      floatingActionButton: MapControls(
        mapController: _mapController,
        currentBaseLayer: _currentBaseLayer,
        locationsCount: _locations.length,
        onLayerSelectorPressed: _showLayerSelector,
        onGpsPressed: _centerOnGpsLocation,
        onLocationsPressed: _locations.isNotEmpty ? _showLocationsSheet : null,
      ),
    );
  }

  /// Show bottom sheet with saved locations
  void _showLocationsSheet() {
    SavedLocationsSheet.show(
      context: context,
      locations: _locations,
      logs: _geolocatedLogs,
      parcels: _parcels,
      onNavigate: (target) {
        setNavigationTarget(target, zoomIn: true);
      },
      onEdit: (location) {
        _editLocation(location);
      },
      onDelete: (location) {
        _showDeleteLocationDialog(location);
      },
    );
  }

  /// Show detailed usage rights dialog
  void _showUsageRightsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Pravice uporabe podatkov',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildUsageRightsSection(
                      context,
                      'Geodetska uprava RS',
                      'prostor.zgs.gov.si',
                      'Podatki Geodetske uprave Republike Slovenije (ortofoto, kataster, '
                          'topografske karte) so na voljo pod pogoji odprtih podatkov. '
                          'Uporaba je dovoljena za nekomercialne in komercialne namene '
                          'ob navedbi vira.',
                      'https://www.gov.si/drzavni-organi/organi-v-sestavi/geodetska-uprava/',
                    ),
                    _buildUsageRightsSection(
                      context,
                      'Zavod za gozdove Slovenije',
                      'ZGS',
                      'Gozdarski podatki (gozdne združbe, sestojna karta, rastiščni koeficienti) '
                          'so javno dostopni. Uporaba je dovoljena za informativne namene. '
                          'Za komercialno uporabo je potrebno pridobiti dovoljenje ZGS.',
                      'https://www.zgs.si/',
                    ),
                    _buildUsageRightsSection(
                      context,
                      'OpenStreetMap',
                      'OSM',
                      'Kartografski podatki OpenStreetMap so na voljo pod licenco '
                          'Open Database License (ODbL). Uporaba je dovoljena ob navedbi '
                          '"© OpenStreetMap contributors".',
                      'https://www.openstreetmap.org/copyright',
                    ),
                    _buildUsageRightsSection(
                      context,
                      'ESRI',
                      'Esri',
                      'Esri satelitski posnetki so na voljo za osebno in nekomercialno '
                          'uporabo. Za komercialno uporabo je potrebna licenca.',
                      'https://www.esri.com/en-us/legal/terms/full-master-agreement',
                    ),
                    _buildUsageRightsSection(
                      context,
                      'Google',
                      'Google',
                      'Google Maps podatki so na voljo pod pogoji Google Maps Platform. '
                          'Uporaba je dovoljena za osebne namene v skladu s pogoji uporabe.',
                      'https://cloud.google.com/maps-platform/terms',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ta aplikacija je namenjena informativni uporabi. '
                              'Za uradne podatke se obrnite na pristojne institucije.',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a single usage rights section
  Widget _buildUsageRightsSection(
    BuildContext context,
    String title,
    String shortName,
    String description,
    String url,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  shortName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            url,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  /// Build attribution text from base layer and active overlays
  String _buildAttributionText() {
    final attributions = <String>{};

    // Add base layer attribution
    if (_currentBaseLayer.attribution.isNotEmpty) {
      attributions.add(_currentBaseLayer.attribution);
    }

    // Add active overlay attributions
    for (final overlayType in _activeOverlays) {
      final layer = MapLayer.overlayLayers.cast<MapLayer?>().firstWhere(
        (l) => l?.type == overlayType,
        orElse: () => null,
      );
      if (layer != null && layer.attribution.isNotEmpty) {
        attributions.add(layer.attribution);
      }
    }

    // Join unique attributions
    return attributions.join(' | ');
  }

  /// Edit location name
  Future<void> _editLocation(MapLocation location) async {
    final newName = await MapDialogs.showEditLocationDialog(
      context: context,
      location: location,
    );

    if (newName != null) {
      final db = DatabaseService();
      await db.updateLocationName(location.id, newName);
      await _loadLocations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lokacija preimenovana v "$newName"')),
        );
      }
    }
  }
}

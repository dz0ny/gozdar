import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../router/navigation_notifier.dart';
import '../router/route_names.dart';
import '../models/map_location.dart';
import '../models/map_layer.dart';
import '../models/parcel.dart';
import '../models/navigation_target.dart';
import '../models/log_entry.dart';
import '../utils/slovenian_crs.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../widgets/log_entry_form.dart';
import '../services/cadastral_service.dart';
import '../services/geopackage_service.dart';
import '../services/tile_cache_service.dart';
import '../widgets/navigation_compass_dialog.dart';
import '../widgets/tile_download_dialog.dart';
import '../widgets/map_long_press_menu.dart';
import '../widgets/navigation_target_banner.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_layer_selector.dart';
import '../widgets/map_dialogs.dart';
import '../widgets/saved_locations_sheet.dart';
import '../widgets/parcel_search_dialog.dart';
import '../widgets/map_marker_renderer.dart';
import '../widgets/map_layer_renderer.dart';
import '../widgets/location_tracker.dart';
import '../widgets/map_dialog_manager.dart';
import '../widgets/parcel_found_sheet.dart';
import 'parcel_detail_screen.dart';
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
  final TileCacheService _tileCacheService = TileCacheService();

  // User location tracking
  late final LocationTracker _locationTracker;
  late final MapDialogManager _dialogManager;

  // Long press menu state
  Offset? _longPressScreenPosition;
  LatLng? _longPressMapPosition;

  // Current zoom level for dynamic marker sizing
  double _currentZoom = 13.0;

  // Searched parcel from WFS query
  WfsParcel? _searchedParcel;

  /// Calculate marker size based on zoom level
  /// Returns smaller sizes at lower zoom levels
  double _getMarkerSize(double baseSize, MapProvider mapProvider) {
    if (mapProvider.currentBaseLayer.isWms && mapProvider.workerUrl == null) {
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
    final mapProvider = context.read<MapProvider>();
    mapProvider.setNavigationTarget(target);
    AnalyticsService().logNavigationStarted();

    // Center map on target location
    final currentRotation = _mapController.camera.rotation;
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = zoomIn
        ? 17.0.clamp(7.0, mapProvider.currentBaseLayer.maxZoom)
        : currentZoom;
    _mapController.moveAndRotate(target.location, targetZoom, currentRotation);
  }

  /// Clear navigation target
  void clearNavigationTarget() {
    context.read<MapProvider>().clearNavigationTarget();
  }

  /// Show compass dialog for navigation target
  void _showCompassForTarget() {
    final navigationTarget = context.read<MapProvider>().navigationTarget;
    if (navigationTarget == null) return;
    AnalyticsService().logCompassOpened();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: NavigationCompassDialog(
          targetLocation: navigationTarget.location,
          targetName: navigationTarget.name,
        ),
      ),
    );
  }

  /// Show tile download dialog (triggered by triple-tap on Karta tab)
  void showTileDownloadDialog() {
    final bounds = _mapController.camera.visibleBounds;
    final currentLayer = context.read<MapProvider>().currentBaseLayer;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: TileDownloadDialog(
          currentLayer: currentLayer,
          bounds: bounds,
          currentZoom: _currentZoom.toInt(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _locationTracker = LocationTracker(
      onLocationUpdate: (position, heading) {
        if (mounted) {
          setState(() {
            // LocationTracker already updated its internal state
          });
        }
      },
    );
    _dialogManager = MapDialogManager(
      context: context,
      onDeleteLocation: _showDeleteLocationDialog,
      onShowTileDownloadDialog: showTileDownloadDialog,
      onResetOnboarding: null, // TODO: Implement onboarding reset
    );
    _initializeData();
    _initializeLocationTracking();
  }

  /// Initialize data loading from provider
  Future<void> _initializeData() async {
    final mapProvider = context.read<MapProvider>();
    await mapProvider.loadPreferences();
    _currentZoom = mapProvider.zoom;
    await Future.wait([
      mapProvider.loadLocations(),
      mapProvider.loadParcels(),
      mapProvider.loadGeolocatedLogs(),
    ]);
  }

  /// Save current map state to preferences
  Future<void> _saveMapState() async {
    final camera = _mapController.camera;
    final mapProvider = context.read<MapProvider>();
    await mapProvider.saveMapState(
      center: camera.center,
      zoom: camera.zoom,
      rotation: camera.rotation,
    );
  }

  @override
  void dispose() {
    _locationTracker.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Initialize real-time location and compass tracking
  Future<void> _initializeLocationTracking() async {
    await _locationTracker.initialize();
  }

  /// Center map on user's current GPS location
  Future<void> _centerOnGpsLocation() async {
    // Capture provider before async operations
    final mapProvider = context.read<MapProvider>();

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
      final currentLayer = mapProvider.currentBaseLayer;
      final targetZoom = 15.0.clamp(7.0, currentLayer.maxZoom);
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
      final mapProvider = context.read<MapProvider>();
      final success = await mapProvider.addLocation(location);

      if (mounted) {
        if (success) {
          AnalyticsService().logLocationAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dodano "$name"')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka: ${mapProvider.error}')),
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

      final mapProvider = context.read<MapProvider>();
      final success = await mapProvider.addLocation(location);

      if (mounted) {
        if (success) {
          AnalyticsService().logSecnjaAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sečnja "$name" označena')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka: ${mapProvider.error}')),
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

    if (result != null && mounted) {
      final mapProvider = context.read<MapProvider>();
      try {
        await DatabaseService().insertLog(result);
        await mapProvider.loadGeolocatedLogs();
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

  /// Navigate to parcel detail screen
  Future<void> _navigateToParcelDetail(Parcel parcel) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ParcelDetailScreen(parcel: parcel),
      ),
    );
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
        final mapProvider = context.read<MapProvider>();
        final success = await mapProvider.deleteLocation(location.id);

        if (mounted) {
          if (success) {
            AnalyticsService().logLocationDeleted();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Izbrisano "${location.name}"')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Napaka: ${mapProvider.error}')),
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
    final mapProvider = context.read<MapProvider>();
    if (mapProvider.isQueryingParcel) return;

    try {
      final parcel = await mapProvider.queryParcelAtLocation(location);

      if (!mounted) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri iskanju parcele: $e')),
        );
      }
    }
  }

  /// Show dialog to import a cadastral parcel or view it if already imported
  Future<void> _showImportParcelDialog(CadastralParcel cadastralParcel) async {
    // Check if parcel already exists using database service
    final dbService = DatabaseService();
    final existingParcel = await dbService.findParcelByKoAndNumber(
      cadastralParcel.cadastralMunicipality,
      cadastralParcel.parcelNumber,
    );

    if (!mounted) return;

    if (existingParcel != null) {
      // Parcel already exists - show option to view it
      final viewParcel = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Parcela že obstaja'),
          content: Text(
            'Parcela ${cadastralParcel.cadastralMunicipality} - ${cadastralParcel.parcelNumber} je že v vaših parcelah.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Zapri'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.visibility),
              label: const Text('Prikaži v mojih parcelah'),
            ),
          ],
        ),
      );

      if (viewParcel == true && mounted) {
        context.read<NavigationNotifier>().navigateToForestWithParcel(existingParcel);
        context.go(AppRoutes.parcelDetail(existingParcel.id));
      }
      return;
    }

    // Parcel doesn't exist - show import dialog
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
      final mapProvider = context.read<MapProvider>();
      final success = await mapProvider.importCadastralParcel(cadastralParcel);

      if (mounted) {
        if (success) {
          AnalyticsService().logParcelImportedCadastral();
          // Download tiles for offline use in the background
          _downloadTilesForParcel(cadastralParcel.polygon);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Parcela ${cadastralParcel.cadastralMunicipality} - ${cadastralParcel.parcelNumber} uspesno uvozena',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka: ${mapProvider.error}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri uvozu parcele: $e')),
        );
      }
    }
  }

  /// Import geodata from file (KML, KMZ, or GeoPackage)
  Future<void> _importGeoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kml', 'kmz', 'gpkg'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final ext = result.files.first.extension?.toLowerCase();

      // Handle GeoPackage import
      if (ext == 'gpkg') {
        final importResult = await GeoPackageService.importFromGeoPackage(
          file.path,
        );

        if (importResult.totalCount == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('V datoteki ni veljavnih podatkov')),
            );
          }
          return;
        }

        // Confirm import
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Uvozi podatke'),
            content: Text(
              'Najdenih ${importResult.totalCount} objektov v datoteki "${importResult.layerName}". Jih uvozim?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Prekliči'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Uvozi'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // Insert all data
          final dbService = DatabaseService();
          for (final parcel in importResult.parcels) {
            await dbService.insertParcel(parcel);
          }
          for (final location in importResult.locations) {
            await dbService.insertLocation(location);
          }
          for (final overlay in importResult.overlays) {
            await dbService.insertOverlay(overlay);
          }

          // Reload data via provider
          if (mounted) {
            final mapProvider = context.read<MapProvider>();
            await Future.wait([
              mapProvider.loadParcels(),
              mapProvider.loadLocations(),
            ]);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Uvoženih ${importResult.totalCount} objektov'),
                ),
              );
            }
          }
        }
        return;
      }

      // TODO: Handle KML/KMZ import
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KML/KMZ uvoz še ni podprt preko karte'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri uvozu: $e')),
        );
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

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    // Start background download (fire-and-forget)
    _tileCacheService.downloadForParcelBounds(bounds);
  }

  /// Switch base layer while preserving current position
  void _switchBaseLayer(MapLayer newLayer) {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;

    // Clamp zoom to new layer's max zoom
    final newZoom = currentZoom.clamp(7.0, newLayer.maxZoom);

    // Update provider
    context.read<MapProvider>().setBaseLayer(newLayer);

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
  }

  /// Show layer selection bottom sheet
  Future<void> _showLayerSelector() async {
    final mapProvider = context.read<MapProvider>();
    await MapLayerSelector.show(
      context: context,
      currentBaseLayer: mapProvider.currentBaseLayer,
      activeOverlays: mapProvider.activeOverlays,
      workerUrl: mapProvider.workerUrl,
      onBaseLayerChanged: (layer) {
        _switchBaseLayer(layer);
      },
      onOverlayToggled: (type) {
        final wasEnabled = mapProvider.activeOverlays.contains(type);
        mapProvider.toggleOverlay(type);
        AnalyticsService().logMapOverlayToggled(
          overlayName: type.name,
          enabled: !wasEnabled,
        );
      },
      onImportFile: _importGeoFile,
      onDownloadTiles: showTileDownloadDialog,
    );
  }

  /// Build tile layer for a specific layer
  /// All layers are cached for up to 1 year

  @override
  Widget build(BuildContext context) {
    // Watch provider for changes (including worker URL, parcels, locations)
    final mapProvider = context.watch<MapProvider>();

    // Create marker renderer using provider data directly
    final markerRenderer = MapMarkerRenderer(
      currentZoom: _currentZoom,
      locations: mapProvider.locations,
      parcels: mapProvider.parcels,
      geolocatedLogs: mapProvider.geolocatedLogs,
      userPosition: _locationTracker.userPosition != null
          ? LatLng(
              _locationTracker.userPosition!.latitude,
              _locationTracker.userPosition!.longitude,
            )
          : null,
      userHeading: _locationTracker.userHeading,
      primaryColor: Theme.of(context).colorScheme.primary,
      onLocationTap: (point, name) => setNavigationTarget(
        NavigationTarget(location: point, name: name),
        zoomIn: false,
      ),
      onLocationLongPress: _dialogManager.showDeleteLocationDialog,
      onLogTap: (point, name) => setNavigationTarget(
        NavigationTarget(location: point, name: name),
        zoomIn: false,
      ),
      onParcelVertexTap: (point, name) => setNavigationTarget(
        NavigationTarget(location: point, name: name),
        zoomIn: false,
      ),
    );

    // Create layer renderer using provider data
    final layerRenderer = MapLayerRenderer(
      baseLayer: mapProvider.currentBaseLayer,
      activeOverlays: mapProvider.activeOverlays,
      workerUrl: mapProvider.workerUrl,
    );

    // Show loading indicator while preferences are loading
    if (!mapProvider.isPreferencesLoaded) {
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
                  (mapProvider.currentBaseLayer.isWms &&
                      mapProvider.workerUrl == null)
                  ? slovenianCrs
                  : const Epsg3857(),
              initialCenter: mapProvider.center,
              initialZoom: mapProvider.zoom,
              initialRotation: mapProvider.rotation,
              minZoom: 7.0,
              maxZoom: mapProvider.currentBaseLayer.maxZoom,
              // Move to saved position when map is ready
              onMapReady: () {
                _mapController.moveAndRotate(
                  mapProvider.center,
                  mapProvider.zoom,
                  mapProvider.rotation,
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
              ...layerRenderer.getAllTileLayers(),
              // Saved parcels as polygons
              if (mapProvider.parcels.isNotEmpty)
                PolygonLayer(
                  polygons: mapProvider.parcels
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

              // Searched parcel (highlighted)
              if (_searchedParcel != null &&
                  _searchedParcel!.polygon.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _searchedParcel!.polygon,
                      color: Colors.blue.withValues(alpha: 0.3),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 3.0,
                      label: 'Parcela ${_searchedParcel!.label}',
                      labelStyle: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.white, blurRadius: 2)],
                      ),
                    ),
                  ],
                ),
              // All markers using the unified renderer
              MarkerLayer(markers: markerRenderer.getAllMarkers()),
              // Navigation target line (from user to target)
              if (mapProvider.navigationTarget != null &&
                  _locationTracker.userPosition != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(
                          _locationTracker.userPosition!.latitude,
                          _locationTracker.userPosition!.longitude,
                        ),
                        mapProvider.navigationTarget!.location,
                      ],
                      color: Colors.orange.withValues(alpha: 0.6),
                      strokeWidth: 3,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
              // Navigation target marker
              if (mapProvider.navigationTarget != null)
                Builder(
                  builder: (ctx) {
                    final navSize = _getMarkerSize(50, mapProvider);
                    final navIconSize = _getMarkerSize(28, mapProvider);
                    final navBorderWidth = _getMarkerSize(3, mapProvider);
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: mapProvider.navigationTarget!.location,
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
          if (mapProvider.navigationTarget != null)
            NavigationTargetBanner(
              target: mapProvider.navigationTarget!,
              onTap: _showCompassForTarget,
              onClose: clearNavigationTarget,
            ),

          // Loading indicator for locations
          if (mapProvider.isLoadingLocations)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  (mapProvider.navigationTarget != null ? 90 : 16),
              left: 16,
              child: Material(
                elevation: 4,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),

          // Loading indicator for parcel query
          if (mapProvider.isQueryingParcel)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  (mapProvider.navigationTarget != null ? 90 : 16),
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 4,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
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
              builder: (ctx) {
                // Capture position at build time so it persists after onDismiss clears state
                final position = _longPressMapPosition!;
                // Find parcel at this position
                Parcel? parcelAtPosition;
                try {
                  parcelAtPosition = mapProvider.parcels.firstWhere(
                    (parcel) => parcel.containsPoint(position),
                  );
                } catch (_) {
                  parcelAtPosition = null;
                }
                return MapLongPressMenu(
                  screenPosition: _longPressScreenPosition!,
                  mapPosition: position,
                  existingParcel: parcelAtPosition,
                  onAddLocation: () => _showAddLocationDialog(position),
                  onAddLog: () => _showAddLogDialog(position),
                  onAddSecnja: () => _showAddSecnjaDialog(position),
                  onImportParcel: () => _queryParcelAtLocation(position),
                  onViewParcel: parcelAtPosition != null
                      ? () => _navigateToParcelDetail(parcelAtPosition!)
                      : null,
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
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 10,
                    ),
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
        currentBaseLayer: mapProvider.currentBaseLayer,
        locationsCount: mapProvider.locations.length,
        onLayerSelectorPressed: _showLayerSelector,
        onSearchPressed: showParcelSearchDialog,
        onGpsPressed: _centerOnGpsLocation,
        onLocationsPressed: mapProvider.locations.isNotEmpty ? _showLocationsSheet : null,
      ),
    );
  }

  /// Show bottom sheet with saved locations
  void _showLocationsSheet() {
    final mapProvider = context.read<MapProvider>();
    SavedLocationsSheet.show(
      context: context,
      locations: mapProvider.locations,
      logs: mapProvider.geolocatedLogs,
      parcels: mapProvider.parcels,
      onNavigate: (target) {
        setNavigationTarget(target, zoomIn: true);
      },
      onEdit: (location) {
        _editLocation(location);
      },
      onDelete: _dialogManager.showDeleteLocationDialog,
    );
  }

  /// Show detailed usage rights dialog
  /// Show parcel search dialog
  void showParcelSearchDialog() {
    ParcelSearchDialog.show(
      context: context,
      mapController: _mapController,
      onParcelFound: _handleParcelFound,
    );
  }

  /// Handle when a parcel is found from search
  Future<void> _handleParcelFound(WfsParcel parcel) async {
    setState(() {
      _searchedParcel = parcel;
    });

    // Fit map to parcel bounds
    if (parcel.polygon.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(parcel.polygon);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
          maxZoom: 17,
        ),
      );
    }

    // Check if parcel already exists in database
    final koInt = int.tryParse(parcel.koNumber);
    final existingParcel = await DatabaseService().findParcelByKoAndNumber(
      koInt,
      parcel.parcelNumber,
    );

    if (!mounted) return;

    // Show bottom sheet with conditional action
    if (mounted) {
      await ParcelFoundSheet.show(
        context: context,
        wfsParcel: parcel,
        existingParcel: existingParcel,
        onHide: () {
          setState(() {
            _searchedParcel = null;
          });
        },
        onAction: () async {
          // Clear the blue overlay
          setState(() {
            _searchedParcel = null;
          });
          if (existingParcel != null) {
            // Parcel already exists - navigate to Forest tab
            context.read<NavigationNotifier>().navigateToForestWithParcel(existingParcel);
            context.go(AppRoutes.parcelDetail(existingParcel.id));
          } else {
            // Parcel doesn't exist - import it
            await _importSearchedParcel(parcel);
          }
        },
      );
    }
  }

  /// Import the searched parcel into the database
  Future<void> _importSearchedParcel(WfsParcel wfsParcel) async {
    try {
      final dbService = DatabaseService();

      // Convert KO number from string to int
      final koInt = int.tryParse(wfsParcel.koNumber);

      // Check if parcel already exists
      final existingParcel = await dbService.findParcelByKoAndNumber(
        koInt,
        wfsParcel.parcelNumber,
      );

      if (existingParcel != null) {
        // Parcel already exists - show option to view it
        if (mounted) {
          final viewParcel = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Parcela že obstaja'),
              content: Text(
                'Parcela ${wfsParcel.label} je že v vaših parcelah.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Zapri'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Prikaži v mojih parcelah'),
                ),
              ],
            ),
          );

          if (viewParcel == true && mounted) {
            context.read<NavigationNotifier>().navigateToForestWithParcel(existingParcel);
            context.go(AppRoutes.parcelDetail(existingParcel.id));
          }
        }
        return;
      }

      // Convert WfsParcel to Parcel model
      final parcel = Parcel(
        name: '${wfsParcel.koNumber} - ${wfsParcel.parcelNumber}',
        polygon: wfsParcel.polygon,
        cadastralMunicipality: koInt,
        parcelNumber: wfsParcel.parcelNumber,
        createdAt: DateTime.now(),
      );

      await dbService.insertParcel(parcel);

      // Reload parcels in provider
      if (mounted) {
        await context.read<MapProvider>().loadParcels();
      }

      // Clear searched parcel
      setState(() {
        _searchedParcel = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcela je bila uvožena'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Log analytics event
      await AnalyticsService().logParcelImportedWfs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Napaka pri uvozu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
                        color: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
    final mapProvider = context.read<MapProvider>();
    final attributions = <String>{};

    // Add base layer attribution
    if (mapProvider.currentBaseLayer.attribution.isNotEmpty) {
      attributions.add(mapProvider.currentBaseLayer.attribution);
    }

    // Add active overlay attributions
    for (final overlayType in mapProvider.activeOverlays) {
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

    if (newName != null && mounted) {
      final mapProvider = context.read<MapProvider>();
      final db = DatabaseService();
      await db.updateLocationName(location.id, newName);
      await mapProvider.loadLocations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lokacija preimenovana v "$newName"')),
        );
      }
    }
  }
}

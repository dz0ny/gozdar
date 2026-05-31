import 'dart:async';
import 'dart:math' as math;
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
import '../services/database_service.dart';
import '../widgets/log_entry_form.dart';
import '../services/cadastral_service.dart';
import '../services/owner_lookup_service.dart';
import '../services/owner_offline_settings_service.dart';
import '../services/tile_cache_service.dart';
import '../services/rtk_position_service.dart';
import '../services/rtk_bridge_settings.dart';
import '../services/vlake_service.dart';
import '../services/vlake_settings.dart';
import '../widgets/navigation_compass_dialog.dart';
import '../widgets/tile_download_dialog.dart';
import '../widgets/map_long_press_menu.dart';
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
import '../services/location_settings.dart';

enum _MeasurementTool { distance, area }

enum _DistanceUnit { meters, kilometers }

enum _AreaUnit { squareMeters, hectares }

class _MeasurementState {
  final _MeasurementTool? tool;
  final List<LatLng> points;
  final bool isFinished;

  const _MeasurementState({
    this.tool,
    this.points = const [],
    this.isFinished = false,
  });

  bool get isActive => tool != null;

  bool get hasEnoughPoints {
    if (tool == _MeasurementTool.distance) {
      return points.length >= 2;
    }
    if (tool == _MeasurementTool.area) {
      return points.length >= 3;
    }
    return false;
  }

  _MeasurementState copyWith({
    _MeasurementTool? tool,
    List<LatLng>? points,
    bool? isFinished,
    bool clearTool = false,
  }) {
    return _MeasurementState(
      tool: clearTool ? null : (tool ?? this.tool),
      points: points ?? this.points,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

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

  // Visible map bounds, used to cull the Vlake overlay to the viewport.
  LatLngBounds? _visibleBounds;

  /// Minimum zoom at which the Vlake (skid-road) overlay is drawn.
  static const double _vlakeMinZoom = 13.0;

  // Searched parcel from WFS query
  WfsParcel? _searchedParcel;
  _MeasurementState _measurement = const _MeasurementState();
  _DistanceUnit _distanceUnit = _DistanceUnit.meters;
  _AreaUnit _areaUnit = _AreaUnit.hectares;

  /// Calculate marker size based on zoom level
  /// Returns smaller sizes at lower zoom levels
  double _getMarkerSize(double baseSize, MapProvider mapProvider) {
    final scale = ((_currentZoom - 15) / 2).clamp(0.5, 1.0);
    return baseSize * scale;
  }

  /// Build Vlake polylines for the current viewport (culled by bounding box).
  List<Polyline> _buildVlakePolylines() {
    final bounds = _visibleBounds;
    if (bounds == null) return const [];
    final lines = VlakeService.instance.linesInBounds(
      bounds.south,
      bounds.west,
      bounds.north,
      bounds.east,
    );
    return lines
        .map(
          (l) => Polyline(
            points: l.points,
            color: const Color(0xFFFF6D00), // orange skid-road
            strokeWidth: 2.0,
          ),
        )
        .toList();
  }

  /// Set navigation target and center map on it
  void setNavigationTarget(NavigationTarget target, {bool zoomIn = true}) {
    final mapProvider = context.read<MapProvider>();
    mapProvider.setNavigationTarget(target);

    // Center map on target location
    final currentRotation = _mapController.camera.rotation;
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = zoomIn
        ? 17.0.clamp(7.0, MapLayer.appMaxZoom)
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
    final mapProvider = context.read<MapProvider>();
    final activeOverlayLayers = MapLayer.overlayLayers
        .where((layer) => mapProvider.activeOverlays.contains(layer.type))
        .toList();
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
          layers: [mapProvider.currentBaseLayer, ...activeOverlayLayers],
          bounds: bounds,
          currentZoom: _currentZoom.toInt(),
        ),
      ),
    );
  }

  Future<void> _showMeasurementSelector() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        ctx,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Merjenje na karti',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Izberite orodje, nato tapnite na karto za dodajanje tock.',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _buildMeasurementOption(
                  context: ctx,
                  icon: Icons.route,
                  title: 'Izmeri razdaljo',
                  subtitle: 'Polilinija z dolzino v metrih ali kilometrih',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _startMeasurement(_MeasurementTool.distance);
                  },
                ),
                const SizedBox(height: 12),
                _buildMeasurementOption(
                  context: ctx,
                  icon: Icons.square_foot,
                  title: 'Izmeri povrsino',
                  subtitle: 'Pokritost iz poligona v m2 ali ha',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _startMeasurement(_MeasurementTool.area);
                  },
                ),
                if (_measurement.isActive) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _closeMeasurement();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Zapri merjenje'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    rtkPositionService.addListener(_handleRtkPositionUpdate);
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
    rtkPositionService.removeListener(_handleRtkPositionUpdate);
    _locationTracker.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _handleRtkPositionUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Initialize real-time location and compass tracking
  Future<void> _initializeLocationTracking() async {
    await _locationTracker.initialize();
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

      final externalPosition = rtkPositionService.position;
      LatLng target;
      if (externalPosition != null) {
        target = externalPosition.point;
      } else {
        // Get current position
        final position = await Geolocator.getCurrentPosition(
          locationSettings: GozdarLocationSettings.currentPosition,
        );
        target = LatLng(position.latitude, position.longitude);
      }

      // Animate map to current location (respect maxZoom), reset rotation to north
      final targetZoom = 15.0.clamp(7.0, MapLayer.appMaxZoom);
      _mapController.moveAndRotate(
        target,
        targetZoom,
        0, // Reset rotation to north
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri pridobivanju lokacije: $e')),
        );
      }
    }
  }

  /// Show dialog to add a new location with editable coordinates
  Future<void> _showAddLocationDialog(LatLng position) async {
    final result = await MapDialogs.showAddLocationDialog(
      context: context,
      position: position,
    );

    if (result != null) {
      await _addLocation(result.name, result.latitude, result.longitude);
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
        // Online lookup found nothing — try the offline owner fallback before
        // giving up (e.g. no connectivity, or the WMS returned no feature).
        if (_showOfflineOwnerFallback(location)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Na tej lokaciji ni najdene parcele')),
        );
        return;
      }

      // Show import dialog
      await _showImportParcelDialog(parcel);
    } catch (e) {
      if (!mounted) return;
      // Online lookup failed (timeout/connectivity) — try the offline fallback.
      if (_showOfflineOwnerFallback(location)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Napaka pri iskanju parcele: $e')),
      );
    }
  }

  /// Offline fallback: when the online cadastral lookup yields nothing, resolve
  /// the owner from the local parcel bounding boxes (if the toggle is on and the
  /// imported database carries bbox geometry). Shows the top candidate in a
  /// sheet clearly marked as approximate. Returns true when a candidate was
  /// shown, false when the fallback is unavailable or found nothing.
  bool _showOfflineOwnerFallback(LatLng location) {
    if (!OwnerOfflineSettingsService.instance.enabled) return false;
    final service = OwnerLookupService.instance;
    if (!service.isAvailable || !service.hasGeometry) return false;

    final hits = service.findOwnersAt(
      location.latitude,
      location.longitude,
    );
    if (hits.isEmpty) return false;

    // Show the first (smallest bounding box) candidate.
    final hit = hits.first;
    final owner = hit.owner.isNotEmpty ? hit.owner : 'Neznan lastnik';
    final details = [
      'Parcela ${hit.parcela} (KO ${hit.koLabel})',
      if (hit.address != null) hit.address!,
    ].join('\n');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_searching,
                      color: colorScheme.tertiary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lastnik (offline)',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: colorScheme.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '≈ približno (brez povezave)',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(Icons.person, color: colorScheme.tertiary),
                  title: Text(
                    owner,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      details,
                      style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.close),
                label: const Text('Zapri'),
              ),
            ],
          ),
        );
      },
    );
    return true;
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

  /// Import geodata from file (KML or KMZ)
  Future<void> _importGeoFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kml', 'kmz'],
      );

      if (result == null || result.files.isEmpty) return;

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
    final newZoom = currentZoom.clamp(7.0, MapLayer.appMaxZoom);

    // Update provider
    context.read<MapProvider>().setBaseLayer(newLayer);

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
    final vlakeSettings = VlakeSettings.instance;
    await MapLayerSelector.show(
      context: context,
      currentBaseLayer: mapProvider.currentBaseLayer,
      activeOverlays: mapProvider.activeOverlays,
      workerUrl: mapProvider.workerUrl,
      onBaseLayerChanged: (layer) {
        _switchBaseLayer(layer);
      },
      onOverlayToggled: (type) {
        mapProvider.toggleOverlay(type);
      },
      onImportFile: _importGeoFile,
      onDownloadTiles: showTileDownloadDialog,
      vlakeAvailable: vlakeSettings.enabled,
      vlakeVisible: vlakeSettings.visible,
      onVlakeToggled: (visible) => vlakeSettings.setVisible(visible),
    );
  }

  Widget _buildMeasurementOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startMeasurement(_MeasurementTool tool) {
    setState(() {
      _longPressScreenPosition = null;
      _longPressMapPosition = null;
      _measurement = _MeasurementState(tool: tool);
    });
  }

  /// Start a measurement seeded with a first point (used from the long-press
  /// menu, where the long-press location becomes the first point).
  void _startMeasurementAt(_MeasurementTool tool, LatLng point) {
    setState(() {
      _longPressScreenPosition = null;
      _longPressMapPosition = null;
      _measurement = _MeasurementState(tool: tool, points: [point]);
    });
  }

  void _addMeasurementPoint(LatLng point) {
    if (!_measurement.isActive || _measurement.isFinished) return;

    setState(() {
      _measurement = _measurement.copyWith(
        points: [..._measurement.points, point],
      );
    });
  }

  void _closeMeasurement() {
    setState(() {
      _measurement = const _MeasurementState();
    });
  }

  double _measurementDistanceMeters(List<LatLng> points) {
    if (points.length < 2) return 0;

    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }

    return total;
  }

  double _measurementAreaM2(List<LatLng> points) {
    if (points.length < 3) return 0;

    final centerLat = points
            .map((p) => p.latitude)
            .reduce((a, b) => a + b) /
        points.length;

    final metersPerDegreeLat = 111132.92 -
        559.82 * math.cos(2 * centerLat * math.pi / 180) +
        1.175 * math.cos(4 * centerLat * math.pi / 180);
    final metersPerDegreeLon = 111412.84 * math.cos(centerLat * math.pi / 180) -
        93.5 * math.cos(3 * centerLat * math.pi / 180);

    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      final x1 = points[i].longitude * metersPerDegreeLon;
      final y1 = points[i].latitude * metersPerDegreeLat;
      final x2 = points[j].longitude * metersPerDegreeLon;
      final y2 = points[j].latitude * metersPerDegreeLat;

      area += x1 * y2 - x2 * y1;
    }

    return area.abs() / 2;
  }

  String _measurementValueLabel() {
    if (!_measurement.isActive) {
      return 'Ni aktivnega merjenja';
    }

    if (_measurement.tool == _MeasurementTool.distance) {
      final meters = _measurementDistanceMeters(_measurement.points);
      if (_distanceUnit == _DistanceUnit.kilometers) {
        return '${(meters / 1000).toStringAsFixed(2)} km';
      }
      return '${meters.toStringAsFixed(0)} m';
    }

    final area = _measurementAreaM2(_measurement.points);
    if (_areaUnit == _AreaUnit.hectares) {
      return '${(area / 10000).toStringAsFixed(2)} ha';
    }
    return '${area.toStringAsFixed(0)} m²';
  }

  /// Compact segmented control to switch measurement display units.
  Widget _measurementUnitSelector() {
    final style = SegmentedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      textStyle: Theme.of(context).textTheme.labelMedium,
    );
    if (_measurement.tool == _MeasurementTool.distance) {
      return SegmentedButton<_DistanceUnit>(
        style: style,
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _DistanceUnit.meters, label: Text('m')),
          ButtonSegment(value: _DistanceUnit.kilometers, label: Text('km')),
        ],
        selected: {_distanceUnit},
        onSelectionChanged: (s) => setState(() => _distanceUnit = s.first),
      );
    }
    return SegmentedButton<_AreaUnit>(
      style: style,
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: _AreaUnit.squareMeters, label: Text('m²')),
        ButtonSegment(value: _AreaUnit.hectares, label: Text('ha')),
      ],
      selected: {_areaUnit},
      onSelectionChanged: (s) => setState(() => _areaUnit = s.first),
    );
  }

  String _measurementHintLabel() {
    if (!_measurement.isActive) {
      return 'Odprite Sloji karte za zacetek merjenja.';
    }
    if (_measurement.isFinished) {
      return 'Merjenje je zakljuceno.';
    }
    if (_measurement.tool == _MeasurementTool.distance) {
      if (_measurement.points.length < 2) {
        return 'Tapnite na karto za dodajanje tock razdalje.';
      }
      return 'Dodajte naslednjo tocko ali zakljucite merjenje.';
    }
    if (_measurement.points.length < 3) {
      return 'Za povrsino potrebujete vsaj 3 tocke.';
    }
    return 'Dodajte naslednjo tocko ali zakljucite poligon.';
  }

  List<Marker> _measurementMarkers() {
    return _measurement.points.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;

      return Marker(
        point: point,
        width: 34,
        height: 34,
        child: Container(
          decoration: BoxDecoration(
            color: _measurement.tool == _MeasurementTool.area
                ? Colors.deepPurple
                : Colors.teal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  String _rtkFixLabel(int? fixQuality) {
    switch (fixQuality) {
      case 4:
        return 'RTK fixed';
      case 5:
        return 'RTK float';
      case 2:
        return 'DGPS';
      case 1:
        return 'GPS';
      default:
        return '-';
    }
  }

  String _rtkAccuracyLabel(double? accuracyMeters) {
    if (accuracyMeters == null) return '-';
    if (accuracyMeters < 1) return '${(accuracyMeters * 100).round()} cm';
    return '${accuracyMeters.toStringAsFixed(1)} m';
  }

  Color _rtkStatusColor(int? fixQuality, ColorScheme colorScheme) {
    if (fixQuality == 4) return Colors.green;
    if (fixQuality == 5) return Colors.orange;
    if (fixQuality == 2) return Colors.amber;
    return colorScheme.primary;
  }

  Widget _buildRtkAccuracyBadge(BuildContext context, RtkPosition position) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _rtkStatusColor(position.fixQuality, colorScheme);

    return Material(
      elevation: 5,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      color: colorScheme.surface.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_fixed, size: 18, color: statusColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_rtkFixLabel(position.fixQuality)}  ${_rtkAccuracyLabel(position.accuracyMeters)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                Text(
                  'Sat ${position.satellites ?? '-'}  HDOP ${position.hdop?.toStringAsFixed(1) ?? '-'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        elevation: 12,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        color: cs.surfaceContainerHighest,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: cs.primary, width: 2)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    _measurement.tool == _MeasurementTool.area
                        ? Icons.square_foot
                        : Icons.route,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _measurement.tool == _MeasurementTool.area
                          ? 'Merjenje povrsine'
                          : 'Merjenje razdalje',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _closeMeasurement,
                    child: const Text('Zapri'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _measurementValueLabel(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _measurementUnitSelector(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _measurementHintLabel(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build tile layer for a specific layer
  /// All layers are cached for up to 1 year

  @override
  Widget build(BuildContext context) {
    // Watch provider for changes (including worker URL, parcels, locations)
    final mapProvider = context.watch<MapProvider>();
    final rtkBridgeSettings = context.watch<RtkBridgeSettings>();
    final vlakeEnabled = context.watch<VlakeSettings>().showOnMap;
    // Lazily load the embedded Vlake data the first time the overlay is on.
    if (vlakeEnabled && !VlakeService.instance.isLoaded) {
      VlakeService.instance.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      });
    }
    final externalPosition = rtkPositionService.position;
    final activeUserPosition = externalPosition?.point ??
        (_locationTracker.userPosition != null
            ? LatLng(
                _locationTracker.userPosition!.latitude,
                _locationTracker.userPosition!.longitude,
              )
            : null);

    // Create marker renderer using provider data directly
    final markerRenderer = MapMarkerRenderer(
      currentZoom: _currentZoom,
      locations: mapProvider.locations,
      parcels: mapProvider.parcels,
      geolocatedLogs: mapProvider.geolocatedLogs,
      userPosition: activeUserPosition,
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
      onParcelVertexTap: (point, name) {
        // Open the compass immediately when a parcel boundary marker
        // (parcelni mejnik) is tapped, instead of requiring a second tap
        // on the banner.
        setNavigationTarget(
          NavigationTarget(location: point, name: name),
          zoomIn: false,
        );
        _showCompassForTarget();
      },
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
          ValueListenableBuilder<TileDownloadVisualState>(
            valueListenable: _tileCacheService.downloadVisualStateListenable,
            builder: (context, downloadState, _) => FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                crs: const Epsg3857(),
                initialCenter: mapProvider.center,
                initialZoom: mapProvider.zoom,
                initialRotation: mapProvider.rotation,
                minZoom: 7.0,
                maxZoom: MapLayer.appMaxZoom,
                // Move to saved position when map is ready
                onMapReady: () {
                  _mapController.moveAndRotate(
                    mapProvider.center,
                    mapProvider.zoom,
                    mapProvider.rotation,
                  );
                  if (mounted) {
                    setState(() {
                      _visibleBounds = _mapController.camera.visibleBounds;
                    });
                  }
                },
                // Handle tap to dismiss long press menu
                onTap: (tapPosition, point) {
                  if (_measurement.isActive && !_measurement.isFinished) {
                    _addMeasurementPoint(point);
                    return;
                  }
                  if (_longPressScreenPosition != null) {
                    setState(() {
                      _longPressScreenPosition = null;
                      _longPressMapPosition = null;
                    });
                  }
                },
                // Handle long press to show action menu
                onLongPress: (tapPosition, point) {
                  if (_measurement.isActive) return;
                  setState(() {
                    _longPressScreenPosition = tapPosition.global;
                    _longPressMapPosition = point;
                  });
                },
                // Save map state when position/zoom/rotation changes
                onMapEvent: (event) {
                  if (event is MapEventMoveEnd || event is MapEventRotateEnd) {
                    _saveMapState();
                    _visibleBounds = event.camera.visibleBounds;
                    // Re-cull the Vlake overlay once movement settles.
                    if (VlakeSettings.instance.showOnMap && mounted) {
                      setState(() {});
                    }
                  }
                  // Track zoom level for dynamic marker sizing
                  if (event.camera.zoom != _currentZoom) {
                    setState(() {
                      _currentZoom = event.camera.zoom;
                      _visibleBounds = event.camera.visibleBounds;
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
                // Embedded Vlake (forest skid-road) overlay, viewport-culled.
                if (vlakeEnabled &&
                    _currentZoom >= _vlakeMinZoom &&
                    VlakeService.instance.isLoaded &&
                    _visibleBounds != null)
                  PolylineLayer(polylines: _buildVlakePolylines()),
                if (downloadState.overlays.isNotEmpty)
                  PolygonLayer(
                    polygons: downloadState.overlays
                        .map(
                          (overlay) => Polygon(
                            points: [
                              LatLng(overlay.north, overlay.west),
                              LatLng(overlay.north, overlay.east),
                              LatLng(overlay.south, overlay.east),
                              LatLng(overlay.south, overlay.west),
                            ],
                            color: Colors.cyan.withValues(alpha: 0.22),
                            borderColor: Colors.cyan,
                            borderStrokeWidth: 1.0,
                          ),
                        )
                        .toList(),
                  ),
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
              if (_measurement.tool == _MeasurementTool.area &&
                  _measurement.points.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _measurement.points,
                      color: Colors.deepPurple.withValues(alpha: 0.18),
                      borderColor: Colors.deepPurple,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              if (_measurement.points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _measurement.points,
                      color: _measurement.tool == _MeasurementTool.area
                          ? Colors.deepPurple
                          : Colors.teal,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              if (externalPosition != null && externalPosition.accuracyMeters != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: externalPosition.point,
                      radius: externalPosition.accuracyMeters!,
                      useRadiusInMeter: true,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                      borderColor: Theme.of(context).colorScheme.primary,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              // All markers using the unified renderer
              MarkerLayer(markers: markerRenderer.getAllMarkers()),
              if (_measurement.points.isNotEmpty)
                MarkerLayer(markers: _measurementMarkers()),
              // Navigation target line (from user to target)
              if (mapProvider.navigationTarget != null &&
                  activeUserPosition != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        activeUserPosition,
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
                    final navSize = _getMarkerSize(34, mapProvider);
                    final navIconSize = _getMarkerSize(20, mapProvider);
                    final navBorderWidth = _getMarkerSize(2, mapProvider);
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
          ),
          ValueListenableBuilder<TileDownloadVisualState>(
            valueListenable: _tileCacheService.downloadVisualStateListenable,
            builder: (context, downloadState, _) {
              if (!downloadState.isDownloading && downloadState.overlays.isEmpty) {
                return const SizedBox.shrink();
              }

              return Positioned(
                top: 16,
                left: 16,
                child: Container(
                  width: 210,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prenos kart ${(downloadState.percent * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: downloadState.total == 0 ? null : downloadState.percent,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Preneseno ${downloadState.downloaded}, v predpomnilniku ${downloadState.skipped}, napake ${downloadState.failed} / ${downloadState.total}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (externalPosition != null)
            Positioned(
              top: 16 +
                  MediaQuery.of(context).padding.top +
                  (_tileCacheService.downloadVisualStateListenable.value.isDownloading ||
                          _tileCacheService.downloadVisualStateListenable.value.overlays.isNotEmpty
                      ? 104
                      : 0),
              left: 16,
              child: _buildRtkAccuracyBadge(context, externalPosition),
            ),

          // Loading indicator for locations
          if (mapProvider.isLoadingLocations)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
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
              top: MediaQuery.of(context).padding.top + 16,
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

          if (_measurement.isActive)
            _buildMeasurementPanel(context),

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
                  onMeasureDistance: () =>
                      _startMeasurementAt(_MeasurementTool.distance, position),
                  onMeasureArea: () =>
                      _startMeasurementAt(_MeasurementTool.area, position),
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

          // Attribution overlay (bottom left) - tap to see usage rights.
          // Hidden while measuring so it doesn't overlap the measurement panel.
          if (!_measurement.isActive)
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
        onMeasurePressed: _showMeasurementSelector,
        onSearchPressed: showParcelSearchDialog,
        onRtkPressed: rtkBridgeSettings.enabled ? () => context.push(AppRoutes.rtkBridge) : null,
        onGpsPressed: _centerOnGpsLocation,
        onLocationsPressed: mapProvider.locations.isNotEmpty ? _showLocationsSheet : null,
        hideBottomControls: _measurement.isActive,
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
      onAddByCoordinates: _showAddLocationByCoordinatesDialog,
    );
  }

  /// Show dialog to add location by entering coordinates manually
  Future<void> _showAddLocationByCoordinatesDialog() async {
    final result = await MapDialogs.showAddLocationByCoordinatesDialog(
      context: context,
    );

    if (result != null) {
      await _addLocation(result.name, result.latitude, result.longitude);
      // Center map on newly added location
      _mapController.move(LatLng(result.latitude, result.longitude), 15);
    }
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

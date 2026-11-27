import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/navigation_notifier.dart';
import '../router/route_names.dart';
import '../models/map_location.dart';
import '../models/map_layer.dart';
import '../models/parcel.dart';
import '../models/navigation_target.dart';
import '../services/database_service.dart';
import '../services/hr_owner_service.dart';
import '../services/auction_service.dart';
import '../services/si_valuation_service.dart';
import '../services/ko_locator.dart';
import '../utils/formats.dart';
import '../widgets/download_progress_view.dart';
import '../widgets/owner_list.dart';
import '../widgets/add_log_sheet.dart';
import '../services/address_lookup_service.dart';
import '../services/cadastral_service.dart';
import '../services/owner_lookup_service.dart';
import '../services/public_parcel_settings.dart';
import '../services/map_parcels_worker.dart';
import '../services/parcel_lookup_service.dart';
import '../services/parcel_pdf_service.dart';
import '../services/region_locator.dart';
import '../services/owner_offline_settings_service.dart';
import '../services/tile_cache_service.dart';
import '../services/vlake_service.dart';
import '../services/vlake_settings.dart';
import '../widgets/navigation_compass_dialog.dart';
import '../widgets/tile_download_dialog.dart';
import '../widgets/map_long_press_menu.dart';
import '../widgets/secnja_marking_panel.dart';
import '../widgets/species_management_sheet.dart';
import '../services/secnja_marking.dart';
import '../services/secnja_marking_prefs.dart';
import '../services/species_service.dart';
import '../services/log_input_prefs_service.dart';
import '../widgets/navigate_to_sheet.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_layer_selector.dart';
import '../widgets/map_dialogs.dart';
import '../widgets/sheet_parts.dart';
import '../widgets/saved_locations_sheet.dart';
import '../widgets/parcel_search_dialog.dart';
import '../widgets/map_marker_renderer.dart';
import '../widgets/map_layer_renderer.dart';
import '../widgets/location_tracker.dart';
import '../widgets/navigation_chip.dart';
import '../widgets/user_location_layer.dart';
import '../widgets/map_dialog_manager.dart';
import '../widgets/parcel_found_sheet.dart';
import 'parcel_detail_screen.dart';
import '../providers/map_provider.dart';
import '../services/location_settings.dart';
import '../services/map_preferences_service.dart';
import '../l10n/l10n.dart';

part 'map_tab/measurement_tool.dart';
part 'map_tab/secnja.dart';
part 'map_tab/offline_kataster.dart';
part 'map_tab/parcel_import.dart';
part 'map_tab/layers_menu.dart';
part 'map_tab/measurement.dart';
part 'map_tab/status.dart';
part 'map_tab/search.dart';
part 'map_tab/attribution.dart';

/// Minimum zoom at which the Vlake (skid-road) overlay is drawn.
const double _vlakeMinZoom = 15.0;

/// Minimum zoom at which the offline kataster (local parcels) overlay is
/// drawn. Parcels are dense, so only render when zoomed in.
const double _offlineKatasterMinZoom = 15.0;

/// Minimum zoom at which parcel-number labels are drawn — higher than the
/// outline zoom so labels don't crowd the map until zoomed in close.
const double _offlineKatasterLabelMinZoom = 17.0;

/// Gold of the court auctions layer.
const _auctionGold = Color(0xFFFFB300);

/// Map Tab screen for the Gozdar app
/// Displays an interactive map with support for multiple layers,
/// saved locations, and GPS functionality.
///
/// The state is split over the parts in map_tab/, one per feature, as
/// extensions on [MapTabState].
class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => MapTabState();
}

class MapTabState extends ConsumerState<MapTab> {
  // Map controller for programmatic map control
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TileCacheService _tileCacheService = TileCacheService();

  // User location tracking
  late final LocationTracker _locationTracker;
  late final MapDialogManager _dialogManager;

  // Current zoom level for dynamic marker sizing
  double _currentZoom = 13.0;

  // Visible map bounds, used to cull the Vlake overlay to the viewport.
  LatLngBounds? _visibleBounds;

  /// Cadastral parcels from the offline database, culled to the viewport.
  /// Populated only when an offline parcels DB is loaded and zoomed in.
  List<CadastralParcel> _offlineParcels = const [];

  /// Further pieces of [_offlineParcels] that consist of several separate
  /// ones; drawn like the first piece, without a second label.
  List<({CadastralParcel parcel, List<LatLng> ring})> _offlineExtraParts =
      const [];

  /// Public-owner category per [_offlineParcels] id (state / municipality /
  /// company), for parcels that are publicly owned/managed. Computed in
  /// [_refreshOfflineParcels] so the polygon build stays cheap. Empty
  /// unless at least one category highlight is on.
  Map<String, PublicOwnerCategory> _publicParcelCategory = const {};

  /// Prebuilt polygons for the two offline-kataster layers, rebuilt in
  /// [_refreshOfflineParcels]/[_rebuildOfflinePolygons] rather than in
  /// [build] so a plain rebuild (e.g. a marker animation) doesn't re-map
  /// thousands of parcels. [_offlineFillPolygons] holds the public-owner
  /// category tints (drawn under the outlines); [_offlineOutlinePolygons]
  /// holds the red/category outlines and the parcel-number labels.
  List<Polygon> _offlineFillPolygons = const [];
  List<Polygon> _offlineOutlinePolygons = const [];

  /// Padded bounds the cached parcels were queried for, and the label/category
  /// state they were built with. While the viewport stays inside this rect and
  /// the state is unchanged, [_refreshOfflineParcels] can skip the SQLite query.
  /// Invalidated (set null) when the kataster layer toggles, a region DB loads,
  /// or category/name state changes.
  LatLngBounds? _offlineQueriedBounds;
  bool _offlineQueriedLabels = false;
  bool _offlineQueriedAnyCategory = false;

  /// Debounce timer for mid-gesture zoom refreshes (continuous pinches), so a
  /// query runs at most a few times per gesture instead of every frame.
  Timer? _offlineZoomDebounce;

  /// Settles moves that end without a [MapEventMoveEnd]: the app's own camera
  /// moves (search result, "show on map"), flings and double-tap zooms.
  Timer? _cameraSettleDebounce;

  /// Prebuilt Vlake polylines, rebuilt in [_refreshVlake] rather than in
  /// [build] so a plain rebuild doesn't re-scan ~78k line bounding boxes.
  List<Polyline> _vlakePolylines = const [];

  /// Padded bounds [_vlakePolylines] were culled for. While the viewport stays
  /// inside this rect, [_refreshVlake] skips the scan entirely.
  LatLngBounds? _vlakeQueriedBounds;

  /// Composite keys ("ko|parcela") of parcels whose mejniki (boundary points) are
  /// shown. Per-parcel and transient — toggled from the long-press menu for the
  /// parcel under the press.
  final Set<String> _mejnikiKeys = {};

  /// The offline parcel under an open long-press menu, highlighted pink while
  /// the sheet is shown. Null when no menu is open.
  CadastralParcel? _selectedParcel;

  /// True while the parcel under a new mark is being imported.
  bool _importingSecnjaParcel = false;

  /// Bumped by every [_refreshOfflineParcels], so a slower earlier load can't
  /// overwrite a newer viewport.
  int _offlineLoadGeneration = 0;

  /// Counts address lookups, so a slow one cannot replace a newer result.
  int _addressLookup = 0;

  /// The address lookup that waits for the network; the map shows a pill.
  int? _addressQuery;

  /// setState for the parts in map_tab/, which can't call the protected one.
  void _setState(VoidCallback fn) => setState(fn);

  String _parcelKey(int ko, String parcela) => '$ko|$parcela';

  /// Number of distinct boundary vertices in a polygon ring, ignoring a trailing
  /// point that closes the ring (equal to the first) so it isn't double-marked.
  int _vertexCount(List<LatLng> ring) =>
      (ring.length > 1 && ring.first == ring.last)
      ? ring.length - 1
      : ring.length;

  /// A tappable boundary-point (mejnik) marker. Tapping navigates to the point
  /// with the compass, matching the saved-parcel mejniki behaviour.
  Marker _mejnikMarker(LatLng point, int number, String parcela) {
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setNavigationTarget(
            NavigationTarget(
              location: point,
              name: L10n.current.mapTabMejnikName(number, parcela),
            ),
            zoomIn: false,
          );
          showCompassForTarget();
        },
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
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
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Regions we've already offered to download this session (avoid nagging).
  final Set<String> _promptedRegions = {};
  // Active region download triggered from the map (auto-prompt).
  String? _downloadingRegionName;
  int _regionReceived = 0;
  int? _regionTotal;
  bool _cancelRegionDownload = false;

  // Searched parcel from WFS query
  WfsParcel? _searchedParcel;
  // Queried cadastral parcel shown as a tan dashed preview while the import dialog
  // is open (not yet saved to the database).
  CadastralParcel? _previewParcel;
  // When set, a non-modal import panel is shown over the map for this parcel.
  // The map stays pannable while the panel is open.
  CadastralParcel? _pendingImportParcel;

  /// Long-press point the import panel was opened from, for its back button.
  LatLng? _importBackTo;

  /// Long-press point measuring was started from, for its back button.
  LatLng? _measureBackTo;
  // True while a PDF is being generated for the pending import panel.
  bool _printingParcel = false;
  _MeasurementState _measurement = const _MeasurementState();

  // True once FlutterMap reports onMapReady; the controller works from then.
  bool _mapReady = false;

  // Sečnja marking mode: crosshair at the map centre, one tap per tree.
  bool _secnjaMarking = false;
  final _secnjaPrefs = SecnjaMarkingPrefs();
  List<String> _secnjaSpeciesList = const [];
  String? _secnjaSpecies;
  // Marks made in this session, newest last, for undo and the share prompt.
  final List<MapLocation> _secnjaSession = [];
  String _secnjaTitle = '';
  int _secnjaCount = 0;
  _DistanceUnit _distanceUnit = _DistanceUnit.meters;
  _AreaUnit _areaUnit = _AreaUnit.hectares;

  /// Calculate marker size based on zoom level
  /// Returns smaller sizes at lower zoom levels
  double _getMarkerSize(double baseSize, MapNotifier mapProvider) {
    final scale = ((_currentZoom - 15) / 2).clamp(0.5, 1.0);
    return baseSize * scale;
  }

  /// Recompute the cached Vlake polylines for the current viewport. Culls a
  /// padded bounds (~40% margin) and remembers it so subsequent pans that stay
  /// inside skip the ~78k-line scan entirely. Clears the cache when the overlay
  /// is off, not loaded, or zoomed out. Mirrors [_refreshOfflineParcels].
  void _refreshVlake() {
    final bounds = _visibleBounds;
    if (!ref.read(vlakeSettingsProvider).showOnMap ||
        !VlakeService.instance.isLoaded ||
        bounds == null ||
        _currentZoom < _vlakeMinZoom) {
      _vlakeQueriedBounds = null;
      if (_vlakePolylines.isNotEmpty) {
        setState(() => _vlakePolylines = const []);
      }
      return;
    }

    final cached = _vlakeQueriedBounds;
    if (cached != null && cached.containsBounds(bounds)) return;

    final latPad = (bounds.north - bounds.south) * 0.4;
    final lonPad = (bounds.east - bounds.west) * 0.4;
    final padded = LatLngBounds(
      LatLng(bounds.south - latPad, bounds.west - lonPad),
      LatLng(bounds.north + latPad, bounds.east + lonPad),
    );
    final lines = VlakeService.instance.linesInBounds(
      padded.south,
      padded.west,
      padded.north,
      padded.east,
    );
    _vlakeQueriedBounds = padded;
    setState(() {
      _vlakePolylines = [
        for (final l in lines)
          Polyline(
            points: l.points,
            color: const Color(0xFFFF6D00), // orange skid-road
            strokeWidth: 2.0,
          ),
      ];
    });
  }

  /// Redraw when the auction list, its outlines or the layer toggle change.
  void _onAuctionsChanged() {
    if (mounted) setState(() {});
  }

  /// The public-owner category a parcel should be highlighted with, or null
  /// when it has no public record or that category's highlight is off.
  PublicOwnerCategory? _highlightCategory(CadastralParcel p) {
    final cat = _publicParcelCategory[p.id];
    if (cat != null && PublicParcelSettings.instance.isOn(cat)) return cat;
    return null;
  }

  /// Set navigation target and center map on it
  void setNavigationTarget(NavigationTarget target, {bool zoomIn = true}) {
    final mapProvider = ref.read(mapNotifierProvider.notifier);
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
    ref.read(mapNotifierProvider.notifier).clearNavigationTarget();
  }

  /// Show the compass dialog for the current navigation target (public so the
  /// scaffold can open it for a target that asked to start navigating).
  void showCompassForTarget() {
    final navigationTarget = ref
        .read(mapNotifierProvider.notifier)
        .navigationTarget;
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
        child: Material(
          // ListTiles paint their background and ink on the nearest
          // Material; this one sits above the sheet's colour.
          type: MaterialType.transparency,
          child: NavigationCompassDialog(
            targetLocation: navigationTarget.location,
            targetName: navigationTarget.name,
            onEndNavigation: clearNavigationTarget,
          ),
        ),
      ),
    );
  }

  /// Show tile download dialog (triggered by triple-tap on Karta tab)
  void showTileDownloadDialog() {
    final bounds = _mapController.camera.visibleBounds;
    final mapProvider = ref.read(mapNotifierProvider.notifier);
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
        child: Material(
          // ListTiles paint their background and ink on the nearest
          // Material; this one sits above the sheet's colour.
          type: MaterialType.transparency,
          child: TileDownloadDialog(
            layers: [mapProvider.currentBaseLayer, ...activeOverlayLayers],
            bounds: bounds,
            currentZoom: _currentZoom.toInt(),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    AuctionService.instance.addListener(_onAuctionsChanged);
    if (AuctionService.instance.visible) {
      unawaited(AuctionService.instance.ensureLoaded());
    }
    // No setState per fix: UserLocationLayer and NavigationLineLayer listen
    // to the tracker themselves, so GPS and compass don't rebuild this tab.
    _locationTracker = LocationTracker();
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
    final mapProvider = ref.read(mapNotifierProvider.notifier);
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
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    await mapProvider.saveMapState(
      center: camera.center,
      zoom: camera.zoom,
      rotation: camera.rotation,
    );
  }

  @override
  void dispose() {
    AuctionService.instance.removeListener(_onAuctionsChanged);
    _offlineZoomDebounce?.cancel();
    _cameraSettleDebounce?.cancel();
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
    try {
      // Check location service status
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(L10n.current.mapTabLocationServicesDisabled),
            ),
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
              SnackBar(
                content: Text(L10n.current.mapTabLocationPermissionDenied),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(L10n.current.mapTabLocationPermissionDeniedForever),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: GozdarLocationSettings.currentPosition,
      );
      final target = LatLng(position.latitude, position.longitude);

      // Locate without changing scale; reset rotation to north-up.
      final currentZoom = _mapController.camera.zoom;
      _mapController.moveAndRotate(target, currentZoom, 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabLocationError(e))),
        );
      }
    }
  }

  /// Show dialog to add a new location with editable coordinates
  Future<void> _showAddLocationDialog(LatLng position) async {
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    final points = mapProvider.locations.where((l) => !l.isSecnja).length;
    final parcel = mapProvider.parcels
        .where((p) => p.containsPoint(position))
        .fold<Parcel?>(
          null,
          (best, p) => best == null || p.areaM2 < best.areaM2 ? p : best,
        );
    final result = await MapDialogs.showAddLocationDialog(
      context: context,
      position: position,
      nextNumber: points + 1,
      parcelLabel: parcel == null
          ? null
          : L10n.current.mapTabParcelShort(parcel.parcelNumber ?? parcel.name),
      onBack: () => _showLongPressMenu(position),
    );

    if (result != null) {
      await _addLocation(result.name, result.latitude, result.longitude);
    }
  }

  /// Add a new location to the database
  Future<void> _addLocation(String name, double lat, double lng) async {
    try {
      final location = MapLocation(name: name, latitude: lat, longitude: lng);
      final mapProvider = ref.read(mapNotifierProvider.notifier);
      final success = await mapProvider.addLocation(location);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.current.mapTabLocationAdded(name))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.current.mapTabErrorWithMessage(mapProvider.error ?? ''),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabLocationAddError(e))),
        );
      }
    }
  }

  /// Moves the camera to show [bounds], e.g. a received share.
  void _fitTo(LatLngBounds bounds) {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(64),
        maxZoom: 17,
      ),
    );
    _saveMapState();
  }

  /// Show log entry form with pre-filled location
  Future<void> _showAddLogDialog(LatLng position) async {
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    final parcel = mapProvider.parcels
        .where((p) => p.containsPoint(position))
        .fold<Parcel?>(
          null,
          (best, p) => best == null || p.areaM2 < best.areaM2 ? p : best,
        );
    final prefs = LogInputPrefsService();
    final lastLength = await prefs.getLastLength();
    final species = await prefs.getCurrentSpecies();
    if (!mounted) return;
    final entry = await AddLogSheet.show(
      context: context,
      position: position,
      parcelLabel: parcel == null
          ? null
          : L10n.current.mapTabParcelShort(parcel.parcelNumber ?? parcel.name),
      lastLength: lastLength,
      species: species,
      onBack: () => _showLongPressMenu(position),
    );
    if (entry == null) return;
    try {
      await DatabaseService().insertLog(entry);
      await prefs.saveLastDimensions(entry.diameter!, entry.length!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.current.mapTabLogAdded(Fmt.num(entry.volume, 3)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabLogAddError(e))),
        );
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
        final mapProvider = ref.read(mapNotifierProvider.notifier);
        final success = await mapProvider.deleteLocation(location.id);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.current.mapTabLocationDeleted(location.name),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.current.mapTabErrorWithMessage(mapProvider.error ?? ''),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabLocationDeleteError(e))),
        );
      }
    }
  }

  /// Whether parcel-number labels are currently drawn (names overlay on and
  /// zoomed in past the label threshold).
  bool get _offlineLabelsVisible {
    final overlays = ref.read(mapNotifierProvider.notifier).activeOverlays;
    return overlays.contains(MapLayerType.katasterNazivi) &&
        _currentZoom >= _offlineKatasterLabelMinZoom;
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider for changes (including worker URL, parcels, locations)
    ref.watch(mapNotifierProvider);
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    if (_mapReady) {
      final focus = mapProvider.takePendingFocus();
      if (focus != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitTo(focus));
      }
    }
    final vlakeEnabled = ref.watch(
      vlakeSettingsProvider.select((s) => s.showOnMap),
    );
    // Lazily load the embedded Vlake data the first time the overlay is on.
    if (vlakeEnabled && !VlakeService.instance.isLoaded) {
      VlakeService.instance.ensureLoaded().then((_) {
        if (mounted) _refreshVlake();
      });
    }
    // Create marker renderer using provider data directly
    final markerRenderer = MapMarkerRenderer(
      currentZoom: _currentZoom,
      locations: mapProvider.locations,
      parcels: mapProvider.parcels,
      geolocatedLogs: mapProvider.geolocatedLogs,
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
        showCompassForTarget();
      },
    );

    // Kataster + "Kataster z nazivi" are rendered from the local SQLite DB, so
    // never fetch them over WMS — they stay toggleable, but draw locally.
    final offlineKataster = ParcelLookupService.instance.isAvailable;
    final layerRenderer = MapLayerRenderer(
      baseLayer: mapProvider.currentBaseLayer,
      activeOverlays: mapProvider.activeOverlays,
      workerUrl: mapProvider.workerUrl,
      excludeOverlays: const {
        MapLayerType.kataster,
        MapLayerType.katasterNazivi,
      },
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
                L10n.current.mapTabLoadingMap,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final previewParcelColor = Theme.of(context).colorScheme.primary;
    // Raw window inset: MediaQuery padding/viewPadding read 0 inside this tab
    // because an ancestor strips them, which made the status-bar scrim too short.
    final view = View.of(context);
    final topInset = view.padding.top / view.devicePixelRatio;
    return Scaffold(
      key: _scaffoldKey,
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
                  _mapReady = true;
                  _mapController.moveAndRotate(
                    mapProvider.center,
                    mapProvider.zoom,
                    mapProvider.rotation,
                  );
                  // A share link opened before the map existed.
                  final focus = mapProvider.takePendingFocus();
                  if (focus != null) _fitTo(focus);
                  if (mounted) {
                    setState(() {
                      _visibleBounds = _mapController.camera.visibleBounds;
                    });
                    _refreshOfflineParcels();
                  }
                },
                onTap: (tapPosition, point) {
                  // While measuring, points are added via the "Dodaj točko"
                  // button using the centre crosshair — tapping the map must
                  // not add points, so panning to aim can't drop one by
                  // accident.
                },
                // Handle long press to show action menu as a bottom sheet
                onLongPress: (tapPosition, point) {
                  if (_measurement.isActive || _secnjaMarking) return;
                  _showLongPressMenu(point);
                },
                // Save map state when position/zoom/rotation changes
                onMapEvent: (event) {
                  if (event is MapEventMoveEnd || event is MapEventRotateEnd) {
                    unawaited(_refreshSecnjaHeader());
                    _cameraSettleDebounce?.cancel();
                    _onCameraSettled(event.camera);
                  } else if (event is MapEventMove ||
                      event is MapEventFlingAnimationEnd ||
                      event is MapEventDoubleTapZoomEnd) {
                    // No MoveEnd follows these, so settle once they stop;
                    // a gesture's own MoveEnd cancels this.
                    _cameraSettleDebounce?.cancel();
                    final camera = event.camera;
                    _cameraSettleDebounce = Timer(
                      const Duration(milliseconds: 250),
                      () {
                        if (mounted) _onCameraSettled(camera);
                      },
                    );
                  }
                  // Track zoom level for dynamic marker sizing
                  if (event.camera.zoom != _currentZoom) {
                    final prevZoom = _currentZoom;
                    setState(() {
                      _currentZoom = event.camera.zoom;
                      _visibleBounds = event.camera.visibleBounds;
                    });
                    _onZoomChanged(prevZoom, event.camera.zoom);
                  }
                },
              ),
              children: [
                ...layerRenderer.getAllTileLayers(),
                // Offline kataster: cadastral parcel outlines from the local DB,
                // shown instead of the online WMS proxy when an offline parcels
                // database is loaded.
                // Public-parcel (javne parcele) category fills, drawn *under* all
                // outlines and without their own borders. Keeping fills in a
                // separate lower layer stops a filled parcel from painting over
                // an adjacent parcel's outline (which looked like doubled lines).
                if (offlineKataster && _offlineFillPolygons.isNotEmpty)
                  PolygonLayer(polygons: _offlineFillPolygons),
                // Cadastral outlines + parcel-number labels, drawn on top of the
                // fills so every boundary is a single crisp line. Polygons are
                // prebuilt in _refreshOfflineParcels; drawLabelsLast keeps label
                // painting from interleaving with polygon painting.
                if (offlineKataster && _offlineOutlinePolygons.isNotEmpty)
                  PolygonLayer(
                    drawLabelsLast: true,
                    polygons: _offlineOutlinePolygons,
                  ),
                // Pink highlight on the parcel under an open long-press sheet.
                if (_selectedParcel != null)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _selectedParcel!.polygon,
                        color: const Color(0x33E91E63),
                        borderColor: const Color(0xFFE91E63),
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),
                // Mejniki: tappable boundary-point markers, per parcel — only
                // the parcels toggled on from the long-press menu. Tapping one
                // navigates to that boundary point (compass), like the saved
                // parcel mejniki.
                if (offlineKataster &&
                    _mejnikiKeys.isNotEmpty &&
                    _offlineParcels.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      for (final p in _offlineParcels)
                        if (_mejnikiKeys.contains(
                          _parcelKey(p.cadastralMunicipality, p.parcelNumber),
                        ))
                          for (int i = 0; i < _vertexCount(p.polygon); i++)
                            _mejnikMarker(p.polygon[i], i + 1, p.parcelNumber),
                    ],
                  ),
                // Embedded Vlake (forest skid-road) overlay. Polylines are
                // prebuilt in _refreshVlake (viewport-culled with margin).
                if (vlakeEnabled && _vlakePolylines.isNotEmpty)
                  PolylineLayer(polylines: _vlakePolylines),
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
                // Court auctions in downloaded regions, gold, at every zoom
                // like the saved parcels.
                if (AuctionService.instance.visible &&
                    AuctionService.instance.outlines.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      for (final p in AuctionService.instance.outlines)
                        Polygon(
                          points: p.polygon,
                          color: _auctionGold.withValues(alpha: 0.35),
                          borderColor: _auctionGold,
                          borderStrokeWidth: 3.0,
                        ),
                    ],
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
                          ),
                        )
                        .toList(),
                  ),

                // Queried parcel preview: theme tan with a thick dashed border,
                // so green always means "my parcel". Skipped when an offline
                // parcels DB is loaded — the red offline kataster outline
                // already shows it.
                if (!offlineKataster &&
                    _previewParcel != null &&
                    _previewParcel!.polygon.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _previewParcel!.polygon,
                        color: previewParcelColor.withValues(alpha: 0.18),
                        borderColor: previewParcelColor,
                        borderStrokeWidth: 3.5,
                        pattern: StrokePattern.dashed(segments: const [12, 6]),
                      ),
                    ],
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
                        label: L10n.current.mapTabParcelLabel(
                          _searchedParcel!.label,
                        ),
                        labelStyle: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          shadows: [Shadow(color: Colors.white, blurRadius: 2)],
                        ),
                      ),
                    ],
                  ),
                // Area fill (no border here — the casing+border is drawn as a
                // closed polyline below so it gets the white underlay too).
                if (_measurement.tool == _MeasurementTool.area &&
                    _measurement.points.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _measurement.points,
                        color: Colors.deepPurple.withValues(alpha: 0.18),
                        borderStrokeWidth: 0,
                      ),
                    ],
                  ),
                // Measurement line/border with a white casing underneath so it
                // stays visible over orthophoto imagery. The wider white line is
                // listed first, the coloured line on top.
                if (_measurement.points.length >= 2)
                  Builder(
                    builder: (ctx) {
                      final isArea = _measurement.tool == _MeasurementTool.area;
                      final color = isArea ? Colors.deepPurple : Colors.teal;
                      // For an area, close the ring so the border is continuous.
                      final linePoints =
                          (isArea && _measurement.points.length >= 3)
                          ? [..._measurement.points, _measurement.points.first]
                          : _measurement.points;
                      return PolylineLayer(
                        polylines: [
                          Polyline(
                            points: linePoints,
                            color: Colors.white,
                            strokeWidth: 7,
                          ),
                          Polyline(
                            points: linePoints,
                            color: color,
                            strokeWidth: 3.5,
                          ),
                        ],
                      );
                    },
                  ),
                // All markers using the unified renderer
                MarkerLayer(markers: markerRenderer.getAllMarkers()),
                UserLocationLayer(
                  fix: _locationTracker.fix,
                  size: markerRenderer.getMarkerSize(30),
                  color: Theme.of(context).colorScheme.primary,
                ),
                if (_measurement.points.isNotEmpty)
                  MarkerLayer(markers: _measurementMarkers()),
                // Navigation target line (from user to target)
                if (mapProvider.navigationTarget != null)
                  NavigationLineLayer(
                    fix: _locationTracker.fix,
                    target: mapProvider.navigationTarget!.location,
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
                              onTap: showCompassForTarget,
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
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
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
          // Scrim behind the status bar so the clock and battery stay
          // readable over bright imagery.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + 32,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xA6000000),
                      Color(0x66000000),
                      Color(0x00000000),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
          // Status cards (downloads, lookups) share one column at the top so
          // they stack instead of overlapping each other. The right inset
          // keeps them clear of the layer/search/zoom button column.
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: MapControls.reservedRightInset,
            child: _buildStatusColumn(context, mapProvider),
          ),

          if (_measurement.isActive && !_measurement.isFinished)
            _buildMeasurementCrosshair(context),

          if (_measurement.isActive) _buildMeasurementPanel(context),

          if (_secnjaMarking)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: _MeasurementCrosshair(color: Colors.deepOrange),
                ),
              ),
            ),

          if (_secnjaMarking) _buildSecnjaPanel(),

          // Attribution overlay (bottom left) - tap to see usage rights.
          // Hidden while measuring so it doesn't overlap the measurement panel.
          if (!_measurement.isActive && !_secnjaMarking)
            Positioned(
              bottom: 4,
              left: 4,
              child: GestureDetector(
                onTap: _showUsageRightsDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Non-modal import panel (keeps the map pannable while open).
          if (_pendingImportParcel != null) _buildImportParcelPanel(context),
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
        onLocationsPressed: mapProvider.locations.isNotEmpty
            ? _showLocationsSheet
            : null,
        // The found-parcel sheet (open while _searchedParcel is set) would
        // sit under the GPS button.
        hideBottomControls:
            _measurement.isActive ||
            _secnjaMarking ||
            _pendingImportParcel != null ||
            _searchedParcel != null,
      ),
    );
  }

  /// Show detailed usage rights dialog
  /// Show parcel search dialog
  void showParcelSearchDialog() {
    ParcelSearchDialog.show(
      context: context,
      mapController: _mapController,
      onParcelFound: _handleParcelFound,
      // The sheet takes a void callback. The error handler keeps a failure
      // of the lookup out of the lost-Future hole.
      onAddressFound: (hit) => unawaited(
        _handleAddressFound(hit).catchError((Object e, StackTrace s) {
          debugPrint('Address lookup failed: ${e.runtimeType}\n$s');
        }),
      ),
    );
  }

  /// Edit location name
  Future<void> _editLocation(MapLocation location) async {
    final newName = await MapDialogs.showEditLocationDialog(
      context: context,
      location: location,
    );

    if (newName != null && mounted) {
      final db = DatabaseService();
      await db.updateLocationName(location.id, newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabLocationRenamed(newName))),
        );
      }
    }
  }
}

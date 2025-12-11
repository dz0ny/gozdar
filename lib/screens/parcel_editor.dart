import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parcel.dart';
import '../models/map_layer.dart';
import '../utils/slovenian_crs.dart';
import '../services/tile_cache_service.dart';

class ParcelEditor extends StatefulWidget {
  final Parcel? parcel;
  final void Function(Parcel)? onSave;

  const ParcelEditor({super.key, this.parcel, this.onSave});

  @override
  State<ParcelEditor> createState() => _ParcelEditorState();
}

class _ParcelEditorState extends State<ParcelEditor> {
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();
  final TileCacheService _tileCacheService = TileCacheService();

  List<LatLng> _polygon = [];
  MapLayer _currentBaseLayer = MapLayer.esriWorldImagery;
  final Set<MapLayerType> _activeOverlays = {};
  bool _isDrawing = true;
  ForestType _forestType = ForestType.mixed;

  // Default center (Slovenia)
  static const LatLng _defaultCenter = LatLng(46.0569, 14.5058);
  static const double _defaultZoom = 15.0;

  @override
  void initState() {
    super.initState();
    if (widget.parcel != null) {
      _nameController.text = widget.parcel!.name;
      _polygon = List.from(widget.parcel!.polygon);
      _forestType = widget.parcel!.forestType;
      _isDrawing = false;
      // Fit to polygon bounds after map is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToPolygonBounds();
      });
    } else {
      _centerOnGps();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _centerOnGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      final targetZoom = _defaultZoom.clamp(7.0, _currentBaseLayer.maxZoom);
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        targetZoom,
      );
    } catch (e) {
      // Silently fail - just use default center
    }
  }

  /// Fit map to show all polygon points
  void _fitToPolygonBounds() {
    if (_polygon.isEmpty) return;

    if (_polygon.length == 1) {
      // Single point - just center on it
      _mapController.move(_polygon.first, 17.0);
      return;
    }

    // Calculate bounds from all points
    double minLat = _polygon.first.latitude;
    double maxLat = _polygon.first.latitude;
    double minLng = _polygon.first.longitude;
    double maxLng = _polygon.first.longitude;

    for (final point in _polygon) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
          maxZoom: 18,
        ),
      );
    } catch (e) {
      debugPrint('Error fitting map to polygon bounds: $e');
    }
  }

  void _addPoint(LatLng point) {
    if (!_isDrawing) return;
    setState(() {
      _polygon.add(point);
    });
  }

  void _removeLastPoint() {
    if (_polygon.isEmpty) return;
    setState(() {
      _polygon.removeLast();
    });
  }

  void _clearPolygon() {
    setState(() {
      _polygon.clear();
      _isDrawing = true;
    });
  }

  void _finishDrawing() {
    if (_polygon.length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Narišite vsaj 3 točke')));
      return;
    }
    setState(() {
      _isDrawing = false;
    });
  }

  void _saveParcel() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prosim vnesite ime')));
      return;
    }

    if (_polygon.length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Narišite vsaj 3 točke')));
      return;
    }

    final parcel = Parcel(
      id: widget.parcel?.id ?? 0,
      name: _nameController.text.trim(),
      polygon: _polygon,
      forestType: _forestType,
      createdAt: widget.parcel?.createdAt,
    );

    widget.onSave?.call(parcel);
    context.pop();
  }

  void _switchBaseLayer(MapLayer newLayer) {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;
    final newZoom = currentZoom.clamp(7.0, newLayer.maxZoom);

    setState(() {
      _currentBaseLayer = newLayer;
    });

    if (newZoom != currentZoom) {
      final currentRotation = _mapController.camera.rotation;
      Future.microtask(() {
        if (mounted) {
          _mapController.moveAndRotate(currentCenter, newZoom, currentRotation);
        }
      });
    }
  }

  void _showLayerSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Osnovni sloj',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(height: 1),
                RadioGroup<MapLayerType>(
                  groupValue: _currentBaseLayer.type,
                  onChanged: (value) {
                    if (value != null) {
                      final layer = MapLayer.baseLayers.firstWhere(
                        (l) => l.type == value,
                      );
                      _switchBaseLayer(layer);
                      setModalState(() {});
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: MapLayer.baseLayers
                        .map(
                          (layer) => RadioListTile<MapLayerType>(
                            value: layer.type,
                            title: Text(layer.name),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Prekrivni sloji',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(height: 1),
                ...MapLayer.overlayLayers.map(
                  (layer) => CheckboxListTile(
                    value: _activeOverlays.contains(layer.type),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _activeOverlays.add(layer.type);
                        } else {
                          _activeOverlays.remove(layer.type);
                        }
                      });
                      setModalState(() {});
                    },
                    title: Text(layer.name),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTileLayerForLayer(MapLayer layer) {
    if (layer.isWms) {
      // Use cached tile provider for prostor.zgs.gov.si WMS layers
      final isCacheable =
          layer.wmsBaseUrl?.contains('prostor.zgs.gov.si') ?? false;

      return TileLayer(
        wmsOptions: WMSTileLayerOptions(
          baseUrl: layer.wmsBaseUrl!,
          layers: layer.wmsLayers!,
          styles: layer.wmsStyles != null ? [layer.wmsStyles!] : const [''],
          format: layer.wmsFormat ?? 'image/jpeg',
          transparent: layer.isTransparent,
          crs: slovenianCrs,
        ),
        tileProvider: isCacheable
            ? _tileCacheService.getTileProvider()
            : NetworkTileProvider(),
        userAgentPackageName: 'dev.dz0ny.gozdar',
        maxZoom: layer.maxZoom,
      );
    } else {
      return TileLayer(
        urlTemplate: layer.urlTemplate!,
        maxZoom: layer.maxZoom,
        userAgentPackageName: 'dev.dz0ny.gozdar',
      );
    }
  }

  List<Widget> _buildOverlayLayers() {
    return MapLayer.overlayLayers
        .where((layer) => _activeOverlays.contains(layer.type))
        .map((layer) => _buildTileLayerForLayer(layer))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate area preview
    final areaPreview = _polygon.length >= 3
        ? Parcel(name: '', polygon: _polygon).areaFormatted
        : '---';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.parcel == null ? 'Dodaj parcelo' : 'Uredi parcelo'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveParcel),
        ],
      ),
      body: Column(
        children: [
          // Name input and forest type
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ime parcele',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                SegmentedButton<ForestType>(
                  segments: [
                    const ButtonSegment(
                      value: ForestType.deciduous,
                      label: Text('Listavci'),
                      icon: Icon(Icons.nature),
                    ),
                    ButtonSegment(
                      value: ForestType.mixed,
                      label: const Text('Mešani'),
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.nature,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          Icon(
                            Icons.park,
                            size: 16,
                            color: Colors.green.shade800,
                          ),
                        ],
                      ),
                    ),
                    const ButtonSegment(
                      value: ForestType.coniferous,
                      label: Text('Iglavci'),
                      icon: Icon(Icons.park),
                    ),
                  ],
                  selected: {_forestType},
                  onSelectionChanged: (Set<ForestType> selection) {
                    setState(() {
                      _forestType = selection.first;
                    });
                  },
                ),
              ],
            ),
          ),

          // Info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  _isDrawing ? Icons.touch_app : Icons.check_circle,
                  size: 20,
                  color: _isDrawing ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isDrawing
                        ? 'Tapnite na zemljevid za dodajanje točk (${_polygon.length} točk)'
                        : 'Risanje zaključeno',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  'Površina: $areaPreview',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    // Use Slovenian CRS for WMS layers (EPSG:3794), otherwise default Web Mercator
                    crs: _currentBaseLayer.isWms
                        ? slovenianCrs
                        : const Epsg3857(),
                    initialCenter: widget.parcel?.center ?? _defaultCenter,
                    initialZoom: _defaultZoom,
                    minZoom: 7.0,
                    maxZoom: _currentBaseLayer.maxZoom,
                    onTap: (tapPosition, point) => _addPoint(point),
                  ),
                  children: [
                    _buildTileLayerForLayer(_currentBaseLayer),
                    ..._buildOverlayLayers(),

                    // Draw polygon
                    if (_polygon.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _polygon,
                            color: Colors.green.withValues(alpha: 0.3),
                            borderColor: Colors.green,
                            borderStrokeWidth: 2.0,
                          ),
                        ],
                      ),

                    // Draw lines between points
                    if (_polygon.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _polygon,
                            color: Colors.green,
                            strokeWidth: 2.0,
                          ),
                        ],
                      ),

                    // Draw markers for each point
                    MarkerLayer(
                      markers: _polygon.asMap().entries.map((entry) {
                        final index = entry.key;
                        final point = entry.value;
                        final isFirst = index == 0;
                        final isLast = index == _polygon.length - 1;

                        return Marker(
                          point: point,
                          width: 30,
                          height: 30,
                          child: GestureDetector(
                            onTap: () {
                              if (isLast && _isDrawing) {
                                _removeLastPoint();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isFirst
                                    ? Colors.green
                                    : isLast
                                    ? Colors.orange
                                    : Colors.green.shade300,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
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
                          ),
                        );
                      }).toList(),
                    ),

                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(_currentBaseLayer.attribution),
                      ],
                    ),
                  ],
                ),

                // Layer switcher and zoom controls
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: _showLayerSelector,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.layers, size: 24),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Fit to bounds button (show all points)
                      if (_polygon.isNotEmpty)
                        Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: _fitToPolygonBounds,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.fit_screen, size: 24),
                            ),
                          ),
                        ),
                      if (_polygon.isNotEmpty) const SizedBox(height: 8),
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () {
                                final camera = _mapController.camera;
                                final newZoom = camera.zoom + 1;
                                if (newZoom <= _currentBaseLayer.maxZoom) {
                                  _mapController.moveAndRotate(
                                    camera.center,
                                    newZoom,
                                    camera.rotation,
                                  );
                                }
                              },
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                ),
                                child: const Icon(Icons.add, size: 24),
                              ),
                            ),
                            Container(height: 1, color: Colors.grey.shade300),
                            InkWell(
                              onTap: () {
                                final camera = _mapController.camera;
                                final newZoom = camera.zoom - 1;
                                if (newZoom >= 7.0) {
                                  _mapController.moveAndRotate(
                                    camera.center,
                                    newZoom,
                                    camera.rotation,
                                  );
                                }
                              },
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(8),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(8),
                                  ),
                                ),
                                child: const Icon(Icons.remove, size: 24),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Drawing controls
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _polygon.isEmpty
                                  ? null
                                  : _removeLastPoint,
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text(
                                'Nazaj',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _polygon.isEmpty
                                  ? null
                                  : _clearPolygon,
                              icon: const Icon(Icons.clear),
                              label: const Text('Počisti'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isDrawing
                                ? FilledButton.icon(
                                    onPressed: _polygon.length >= 3
                                        ? _finishDrawing
                                        : null,
                                    icon: const Icon(Icons.check),
                                    label: const Text('Končano'),
                                  )
                                : FilledButton.icon(
                                    onPressed: () =>
                                        setState(() => _isDrawing = true),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Uredi'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/map_layer.dart';
import '../services/tile_cache_service.dart';

/// Handles rendering of map tile layers and overlays
class MapLayerRenderer {
  final MapLayer baseLayer;
  final Set<MapLayerType> activeOverlays;
  final String? workerUrl;

  /// Overlay types to skip even when active — used to suppress the online WMS
  /// kataster proxy when an offline parcels database is rendering those layers
  /// locally.
  final Set<MapLayerType> excludeOverlays;

  const MapLayerRenderer({
    required this.baseLayer,
    required this.activeOverlays,
    this.workerUrl,
    this.excludeOverlays = const {},
  });

  /// Build tile layer for a given layer
  TileLayer buildTileLayerForLayer(MapLayer layer) {
    final tileCacheService = TileCacheService();
    final urlTemplate = layer.resolveUrlTemplate(workerUrl);
    if (urlTemplate == null) {
      throw StateError('Layer ${layer.type.name} requires a worker URL');
    }

    return TileLayer(
      urlTemplate: urlTemplate,
      maxZoom: MapLayer.appMaxZoom,
      maxNativeZoom: layer.nativeMaxZoom,
      minZoom: layer.minZoom,
      tileProvider: tileCacheService.getTileProviderFor(layer),
      userAgentPackageName: 'dev.dz0ny.gozdar',
      errorTileCallback: (tile, error, stackTrace) {
        debugPrint(
          'TILE ERROR [${layer.type.name}] '
          '${tile.coordinates.z}/${tile.coordinates.x}/${tile.coordinates.y}: '
          '$error',
        );
      },
    );
  }

  /// Build tile layer for the base layer
  TileLayer buildBaseTileLayer() {
    return buildTileLayerForLayer(baseLayer);
  }

  /// Build overlay tile layers
  List<TileLayer> buildOverlayLayers() {
    return MapLayer.overlayLayers
        .where((layer) => activeOverlays.contains(layer.type))
        .where((layer) => !excludeOverlays.contains(layer.type))
        .where((layer) => layer.resolveUrlTemplate(workerUrl) != null)
        .map((layer) => buildTileLayerForLayer(layer))
        .toList();
  }

  /// Get all tile layers (base + overlays).
  List<TileLayer> getAllTileLayers() {
    final layers = <TileLayer>[];
    layers.add(buildBaseTileLayer());
    layers.addAll(buildOverlayLayers());
    return layers;
  }
}

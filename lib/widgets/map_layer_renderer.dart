import 'package:flutter_map/flutter_map.dart';
import '../models/map_layer.dart';
import '../services/tile_cache_service.dart';

/// Handles rendering of map tile layers and overlays
class MapLayerRenderer {
  final MapLayer baseLayer;
  final Set<MapLayerType> activeOverlays;
  final String? workerUrl;

  const MapLayerRenderer({
    required this.baseLayer,
    required this.activeOverlays,
    this.workerUrl,
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
      tileProvider: tileCacheService.getGeneralTileProvider(),
      userAgentPackageName: 'dev.dz0ny.gozdar',
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
        .where((layer) => layer.resolveUrlTemplate(workerUrl) != null)
        .map((layer) => buildTileLayerForLayer(layer))
        .toList();
  }

  /// Get all tile layers (base + overlays)
  List<TileLayer> getAllTileLayers() {
    final layers = <TileLayer>[];
    layers.add(buildBaseTileLayer());
    layers.addAll(buildOverlayLayers());
    return layers;
  }
}

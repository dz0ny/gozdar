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

  /// Build tile layer for a given layer; [tileBounds] limits the tiles it
  /// asks for.
  TileLayer buildTileLayerForLayer(MapLayer layer, {LatLngBounds? tileBounds}) {
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
      tileBounds: tileBounds,
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

  /// The base layer with its neighbouring-country orthophoto
  /// ([MapLayer.stackFor]), bottom first. A partner that cannot resolve
  /// (Slovenian, no worker URL) is left out; the partner only fetches tiles
  /// over its own country.
  List<TileLayer> buildBaseTileLayers() => [
    for (final layer in MapLayer.stackFor(baseLayer))
      if (layer == baseLayer)
        buildTileLayerForLayer(layer)
      else if (layer.resolveUrlTemplate(workerUrl) != null)
        buildTileLayerForLayer(layer, tileBounds: layer.orthoCoverage),
  ];

  /// Get all tile layers (base + overlays).
  List<TileLayer> getAllTileLayers() {
    final layers = <TileLayer>[];
    layers.addAll(buildBaseTileLayers());
    layers.addAll(buildOverlayLayers());
    return layers;
  }
}

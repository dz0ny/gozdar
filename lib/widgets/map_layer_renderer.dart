import 'package:flutter_map/flutter_map.dart';
import '../models/map_layer.dart';
import '../services/tile_cache_service.dart';
import '../utils/slovenian_crs.dart';

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

    // If worker URL is set and layer is Slovenian/WMS, use the proxy
    if (workerUrl != null && (layer.isSlovenian || layer.isWms)) {
      // Convert enum name to kebab-case slug
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
        tileProvider: tileCacheService.getGeneralTileProvider(),
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
            ? tileCacheService.getTileProvider()
            : tileCacheService.getGeneralTileProvider(),
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
        tileProvider: tileCacheService.getGeneralTileProvider(),
        userAgentPackageName: 'dev.dz0ny.gozdar',
      );
    }
  }

  /// Build tile layer for the base layer
  TileLayer buildBaseTileLayer() {
    return buildTileLayerForLayer(baseLayer);
  }

  /// Build overlay tile layers
  List<TileLayer> buildOverlayLayers() {
    final isSlovenianBase = baseLayer.isSlovenian;

    return MapLayer.overlayLayers
        .where((layer) => activeOverlays.contains(layer.type))
        .where(
          (layer) => !layer.isSlovenian || isSlovenianBase || workerUrl != null,
        )
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

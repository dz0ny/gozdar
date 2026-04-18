import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_layer.dart';
import 'offline_map_caching_provider.dart';
import 'offline_tile_cache_service.dart';
import 'tile_download_service.dart';
import 'tile_math_service.dart';

/// MeshCore-style offline tile cache wrapper for browsing + predownload.
class TileCacheService {
  static final TileCacheService _instance = TileCacheService._internal();
  static bool _initialized = false;
  static bool _isDownloading = false;
  static bool _ignoreDownloadEvents = false;
  static TileDownloadService? _downloadService;
  static NetworkTileProvider? _tileProvider;
  static final ValueNotifier<TileDownloadVisualState> _downloadVisualState =
      ValueNotifier(const TileDownloadVisualState());

  final OfflineTileCacheService _offlineCache = OfflineTileCacheService.instance;

  factory TileCacheService() {
    return _instance;
  }

  TileCacheService._internal();

  ValueListenable<TileDownloadVisualState> get downloadVisualStateListenable =>
      _downloadVisualState;

  TileDownloadVisualState get currentDownloadVisualState =>
      _downloadVisualState.value;

  static Future<void> initialize() async {
    if (_initialized) return;

    _tileProvider = NetworkTileProvider(
      cachingProvider: OfflineMapCachingProvider(
        BuiltInMapCachingProvider.getOrCreateInstance(
          maxCacheSize: 10_000_000_000,
          overrideFreshAge: const Duration(days: 365),
        ),
      ),
    );
    _initialized = true;
  }

  NetworkTileProvider getTileProvider() {
    if (!_initialized) {
      throw StateError(
        'TileCacheService not initialized. Call TileCacheService.initialize() first.',
      );
    }

    return _tileProvider!;
  }

  NetworkTileProvider getGeneralTileProvider() {
    return getTileProvider();
  }

  Future<Map<String, dynamic>> getStats() async {
    if (!_initialized) {
      return {'initialized': false};
    }

    try {
      final styles = await _offlineCache.listStylesDetailed();
      final totalTiles = styles.fold<int>(0, (sum, style) => sum + style.tileCount);
      final totalBytes = styles.fold<int>(0, (sum, style) => sum + style.sizeBytes);

      return {
        'initialized': true,
        'styles': styles.length,
        'totalTiles': totalTiles,
        'totalSizeMB': (totalBytes / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      return {'initialized': true, 'error': e.toString()};
    }
  }

  Future<void> clearCache() async {
    await _offlineCache.clearCache();
  }

  bool get isDownloading => _isDownloading;

  int estimateTileCount({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) {
    final polygon = [
      LatLng(bounds.north, bounds.west),
      LatLng(bounds.north, bounds.east),
      LatLng(bounds.south, bounds.east),
      LatLng(bounds.south, bounds.west),
    ];

    return TileMathService.estimateTileCount([polygon], minZoom, maxZoom);
  }

  Future<void> downloadLayersForRegion({
    required List<TileDownloadRequest> requests,
    required LatLngBounds bounds,
    Function(double progress)? onProgress,
  }) async {
    if (!_initialized) {
      throw StateError(
        'TileCacheService not initialized. Call TileCacheService.initialize() first.',
      );
    }

    if (_isDownloading) {
      throw StateError('A download is already in progress. Cancel it first.');
    }

    final filteredRequests = requests
        .map(_normalizeDownloadRequest)
        .where((request) => request.urlTemplate.isNotEmpty)
        .where((request) => request.minZoom <= request.maxZoom)
        .toList();
    if (filteredRequests.isEmpty) {
      return;
    }

    _isDownloading = true;
    _ignoreDownloadEvents = false;
    _downloadService = TileDownloadService();

    final polygon = [
      LatLng(bounds.north, bounds.west),
      LatLng(bounds.north, bounds.east),
      LatLng(bounds.south, bounds.east),
      LatLng(bounds.south, bounds.west),
    ];
    final totalTiles = filteredRequests.fold<int>(
      0,
      (sum, request) => sum + estimateTileCount(
        bounds: bounds,
        minZoom: request.minZoom,
        maxZoom: request.maxZoom,
      ),
    );

    _downloadVisualState.value = TileDownloadVisualState(
      isDownloading: true,
      total: totalTiles,
      layerCount: filteredRequests.length,
      currentLayerName: filteredRequests.first.layerName,
    );

    try {
      for (var i = 0; i < filteredRequests.length; i++) {
        final request = filteredRequests[i];
        _downloadVisualState.value = _downloadVisualState.value.copyWith(
          isDownloading: true,
          layerCount: filteredRequests.length,
          currentLayerName: request.layerName,
          layersCompleted: i,
        );

        await for (final event in _downloadService!.downloadTiles(
          polygons: [polygon],
          minZoom: request.minZoom,
          maxZoom: request.maxZoom,
          urlTemplate: request.urlTemplate,
          displayName: request.layerName,
        )) {
          _applyAggregateDownloadEvent(event);
          onProgress?.call(_downloadVisualState.value.percent * 100);
        }

        if (!_downloadVisualState.value.isDownloading) {
          break;
        }
      }
    } finally {
      final wasCancelled = _downloadVisualState.value.isDownloading == false &&
          _downloadVisualState.value.layersCompleted <
              _downloadVisualState.value.layerCount;
      _downloadService?.dispose();
      _downloadService = null;
      _isDownloading = false;
      _downloadVisualState.value = _downloadVisualState.value.copyWith(
        isDownloading: false,
        currentLayerName: wasCancelled
            ? _downloadVisualState.value.currentLayerName
            : '',
        layersCompleted: _downloadVisualState.value.layerCount,
      );
    }
  }

  Future<void> downloadRegion({
    required bool isSlovenian,
    required String urlTemplate,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    Function(double progress)? onProgress,
  }) async {
    await downloadLayersForRegion(
      requests: [
        TileDownloadRequest(
          isSlovenian: isSlovenian,
          urlTemplate: urlTemplate,
          minZoom: minZoom,
          maxZoom: maxZoom,
        ),
      ],
      bounds: bounds,
      onProgress: onProgress,
    );
  }

  Future<void> cancelDownload() async {
    _downloadService?.cancel();
    _isDownloading = false;
    _ignoreDownloadEvents = true;
    clearDownloadVisuals();
  }

  Future<void> downloadForParcelBounds(LatLngBounds bounds) async {
    if (!_initialized || _isDownloading) return;

    const urlTemplate =
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    const minZoom = 14;
    const maxZoom = 17;

    final tileCount = estimateTileCount(
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    if (tileCount > 500) {
      return;
    }

    await downloadRegion(
      isSlovenian: false,
      urlTemplate: urlTemplate,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  void clearDownloadVisuals() {
    _downloadVisualState.value = const TileDownloadVisualState();
  }

  TileDownloadRequest _normalizeDownloadRequest(TileDownloadRequest request) {
    final clampedMaxZoom = request.maxZoom.clamp(
      0,
      MapLayer.tileSourceMaxZoom.toInt(),
    );
    final clampedMinZoom = request.minZoom.clamp(0, clampedMaxZoom);

    return TileDownloadRequest(
      isSlovenian: request.isSlovenian,
      urlTemplate: request.urlTemplate,
      minZoom: clampedMinZoom,
      maxZoom: clampedMaxZoom,
      layerName: request.layerName,
    );
  }

  void _applyAggregateDownloadEvent(TileDownloadEvent event) {
    if (_ignoreDownloadEvents) {
      return;
    }
    final current = _downloadVisualState.value;

    if (event is TileDownloadStarted) {
      return;
    }

    if (event is TileDownloaded) {
      final overlays = [...current.overlays, TileOverlay(
        north: event.north,
        south: event.south,
        east: event.east,
        west: event.west,
      )];
      final trimmed = overlays.length > 500
          ? overlays.sublist(overlays.length - 500)
          : overlays;
      _downloadVisualState.value = current.copyWith(
        downloaded: current.downloaded + 1,
        overlays: trimmed,
      );
      return;
    }

    if (event is TileBatchSkipped) {
      _downloadVisualState.value = current.copyWith(
        skipped: current.skipped + event.count,
      );
      return;
    }

    if (event is TileFailed) {
      _downloadVisualState.value = current.copyWith(
        failed: current.failed + 1,
      );
      return;
    }

    if (event is TileDownloadComplete) {
      _downloadVisualState.value = current.copyWith(
        layersCompleted: current.layersCompleted + 1,
      );
      return;
    }

    if (event is TileDownloadCancelled) {
      _downloadVisualState.value = current.copyWith(isDownloading: false);
    }
  }
}

class TileOverlay {
  final double north;
  final double south;
  final double east;
  final double west;

  const TileOverlay({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });
}

class TileDownloadVisualState {
  final bool isDownloading;
  final int downloaded;
  final int skipped;
  final int failed;
  final int total;
  final int layerCount;
  final int layersCompleted;
  final String? currentLayerName;
  final List<TileOverlay> overlays;

  const TileDownloadVisualState({
    this.isDownloading = false,
    this.downloaded = 0,
    this.skipped = 0,
    this.failed = 0,
    this.total = 0,
    this.layerCount = 0,
    this.layersCompleted = 0,
    this.currentLayerName,
    this.overlays = const [],
  });

  double get percent {
    if (total == 0) return 0;
    return (downloaded + skipped + failed) / total;
  }

  TileDownloadVisualState copyWith({
    bool? isDownloading,
    int? downloaded,
    int? skipped,
    int? failed,
    int? total,
    int? layerCount,
    int? layersCompleted,
    String? currentLayerName,
    List<TileOverlay>? overlays,
  }) {
    return TileDownloadVisualState(
      isDownloading: isDownloading ?? this.isDownloading,
      downloaded: downloaded ?? this.downloaded,
      skipped: skipped ?? this.skipped,
      failed: failed ?? this.failed,
      total: total ?? this.total,
      layerCount: layerCount ?? this.layerCount,
      layersCompleted: layersCompleted ?? this.layersCompleted,
      currentLayerName: currentLayerName != null
          ? (currentLayerName.isEmpty ? null : currentLayerName)
          : this.currentLayerName,
      overlays: overlays ?? this.overlays,
    );
  }
}

class TileDownloadRequest {
  final bool isSlovenian;
  final String urlTemplate;
  final int minZoom;
  final int maxZoom;
  final String? layerName;

  const TileDownloadRequest({
    required this.isSlovenian,
    required this.urlTemplate,
    required this.minZoom,
    required this.maxZoom,
    this.layerName,
  });
}

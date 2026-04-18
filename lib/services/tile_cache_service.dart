import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'offline_map_caching_provider.dart';
import 'offline_tile_cache_service.dart';
import 'tile_download_service.dart';
import 'tile_math_service.dart';

/// MeshCore-style offline tile cache wrapper for browsing + predownload.
class TileCacheService {
  static final TileCacheService _instance = TileCacheService._internal();
  static bool _initialized = false;
  static bool _isDownloading = false;
  static TileDownloadService? _downloadService;
  static NetworkTileProvider? _tileProvider;

  final OfflineTileCacheService _offlineCache = OfflineTileCacheService.instance;

  factory TileCacheService() {
    return _instance;
  }

  TileCacheService._internal();

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

  Future<void> downloadRegion({
    required bool isSlovenian,
    required String urlTemplate,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
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

    _isDownloading = true;
    _downloadService = TileDownloadService();

    try {
      final polygon = [
        LatLng(bounds.north, bounds.west),
        LatLng(bounds.north, bounds.east),
        LatLng(bounds.south, bounds.east),
        LatLng(bounds.south, bounds.west),
      ];

      await for (final event in _downloadService!.downloadTiles(
        polygons: [polygon],
        minZoom: minZoom,
        maxZoom: maxZoom,
        urlTemplate: urlTemplate,
      )) {
        if (onProgress == null) {
          continue;
        }
        if (event is TileDownloadStarted && event.totalTiles == 0) {
          onProgress(100.0);
        }
        if (event is TileDownloadComplete) {
          final processed = event.downloaded + event.skipped + event.failed;
          final progress = event.total == 0
              ? 100.0
              : ((processed / event.total) * 100).toDouble();
          onProgress(progress);
        }
      }
    } finally {
      _downloadService?.dispose();
      _downloadService = null;
      _isDownloading = false;
    }
  }

  Future<void> cancelDownload() async {
    _downloadService?.cancel();
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
}

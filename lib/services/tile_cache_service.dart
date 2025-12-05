import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

/// Service for managing map tile caching
/// Uses flutter_map_tile_caching with ObjectBox backend
class TileCacheService {
  static final TileCacheService _instance = TileCacheService._internal();
  static bool _initialized = false;
  static bool _isDownloading = false;

  // Store name for Slovenian government map tiles (prostor.zgs.gov.si)
  static const String _slovenianStore = 'prostor_zgs';

  // Store name for general map tiles (OSM, ESRI, Google, etc.)
  static const String _generalStore = 'general_tiles';

  // Cache tiles for 1 year (365 days)
  static const Duration _maxAge = Duration(days: 365);

  factory TileCacheService() {
    return _instance;
  }

  TileCacheService._internal();

  /// Initialize the tile caching backend
  /// Must be called before using any tile caching features
  static Future<void> initialize() async {
    if (_initialized) return;

    await FMTCObjectBoxBackend().initialise();
    _initialized = true;

    // Create stores if they don't exist
    final slovenianStore = FMTCStore(_slovenianStore);
    await slovenianStore.manage.create();

    final generalStore = FMTCStore(_generalStore);
    await generalStore.manage.create();
  }

  /// Get the tile provider for Slovenian prostor.zgs.gov.si tiles
  FMTCTileProvider getTileProvider() {
    if (!_initialized) {
      throw StateError('TileCacheService not initialized. Call TileCacheService.initialize() first.');
    }

    return FMTCTileProvider(
      stores: const {_slovenianStore: BrowseStoreStrategy.readUpdateCreate},
      loadingStrategy: BrowseLoadingStrategy.cacheFirst,
      cachedValidDuration: _maxAge,
    );
  }

  /// Get the tile provider for general map tiles (OSM, ESRI, Google, etc.)
  FMTCTileProvider getGeneralTileProvider() {
    if (!_initialized) {
      throw StateError('TileCacheService not initialized. Call TileCacheService.initialize() first.');
    }

    return FMTCTileProvider(
      stores: const {_generalStore: BrowseStoreStrategy.readUpdateCreate},
      loadingStrategy: BrowseLoadingStrategy.cacheFirst,
      cachedValidDuration: _maxAge,
    );
  }

  /// Get cache statistics for all stores
  Future<Map<String, dynamic>> getStats() async {
    if (!_initialized) {
      return {'initialized': false};
    }

    try {
      final slovenianStore = FMTCStore(_slovenianStore);
      final slovenianStats = await slovenianStore.stats.all;

      final generalStore = FMTCStore(_generalStore);
      final generalStats = await generalStore.stats.all;

      return {
        'initialized': true,
        'slovenian': {
          'storeName': _slovenianStore,
          'tileCount': slovenianStats.length,
          'sizeKB': slovenianStats.size,
          'sizeMB': (slovenianStats.size / 1024).toStringAsFixed(2),
          'hits': slovenianStats.hits,
          'misses': slovenianStats.misses,
        },
        'general': {
          'storeName': _generalStore,
          'tileCount': generalStats.length,
          'sizeKB': generalStats.size,
          'sizeMB': (generalStats.size / 1024).toStringAsFixed(2),
          'hits': generalStats.hits,
          'misses': generalStats.misses,
        },
        'totalTiles': slovenianStats.length + generalStats.length,
        'totalSizeMB': ((slovenianStats.size + generalStats.size) / 1024).toStringAsFixed(2),
      };
    } catch (e) {
      return {'initialized': true, 'error': e.toString()};
    }
  }

  /// Clear all cached tiles from all stores
  Future<void> clearCache() async {
    if (!_initialized) return;

    try {
      final slovenianStore = FMTCStore(_slovenianStore);
      await slovenianStore.manage.reset();

      final generalStore = FMTCStore(_generalStore);
      await generalStore.manage.reset();
    } catch (e) {
      // Silently fail
    }
  }

  /// Check if a download is currently in progress
  bool get isDownloading => _isDownloading;

  /// Estimate the number of tiles for a given region and zoom range
  int estimateTileCount({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) {
    int totalTiles = 0;
    for (int z = minZoom; z <= maxZoom; z++) {
      final n = math.pow(2, z).toInt();

      // Convert lat/lng to tile coordinates
      final minX = _lngToTileX(bounds.west, z);
      final maxX = _lngToTileX(bounds.east, z);
      final minY = _latToTileY(bounds.north, z); // north has smaller Y
      final maxY = _latToTileY(bounds.south, z); // south has larger Y

      final tilesX = (maxX - minX + 1).clamp(1, n);
      final tilesY = (maxY - minY + 1).clamp(1, n);

      totalTiles += tilesX * tilesY;
    }
    return totalTiles;
  }

  int _lngToTileX(double lng, int zoom) {
    return ((lng + 180) / 360 * math.pow(2, zoom)).floor();
  }

  int _latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180;
    return ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * math.pow(2, zoom)).floor();
  }

  /// Download tiles for a region
  /// [isSlovenian] - true for prostor.zgs.gov.si tiles, false for general tiles
  /// [urlTemplate] - URL template for tile fetching
  /// [bounds] - geographic bounds to download
  /// [minZoom] - minimum zoom level
  /// [maxZoom] - maximum zoom level
  /// [onProgress] - callback for download progress (0-100)
  Future<void> downloadRegion({
    required bool isSlovenian,
    required String urlTemplate,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    Function(double progress)? onProgress,
  }) async {
    if (!_initialized) {
      throw StateError('TileCacheService not initialized. Call TileCacheService.initialize() first.');
    }

    if (_isDownloading) {
      throw StateError('A download is already in progress. Cancel it first.');
    }

    _isDownloading = true;

    try {
      final storeName = isSlovenian ? _slovenianStore : _generalStore;
      final store = FMTCStore(storeName);
      final region = RectangleRegion(bounds);

      final downloadable = region.toDownloadable(
        minZoom: minZoom,
        maxZoom: maxZoom,
        options: TileLayer(urlTemplate: urlTemplate),
      );

      final download = store.download.startForeground(region: downloadable);

      await for (final progress in download.downloadProgress) {
        if (onProgress != null && progress.maxTilesCount > 0) {
          onProgress(progress.percentageProgress);
        }
      }
    } finally {
      _isDownloading = false;
    }
  }

  /// Cancel the current download
  Future<void> cancelDownload() async {
    if (!_initialized || !_isDownloading) return;

    try {
      final slovenianStore = FMTCStore(_slovenianStore);
      await slovenianStore.download.cancel();

      final generalStore = FMTCStore(_generalStore);
      await generalStore.download.cancel();
    } catch (e) {
      // Silently fail
    } finally {
      _isDownloading = false;
    }
  }
}

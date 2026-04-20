import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import 'database_service.dart';

class DownloadRegion {
  final List<List<List<double>>> polygons;
  final int minZoom;
  final int maxZoom;

  const DownloadRegion({
    required this.polygons,
    required this.minZoom,
    required this.maxZoom,
  });

  Map<String, dynamic> toJson() => {
    'polygons': polygons,
    'minZoom': minZoom,
    'maxZoom': maxZoom,
  };

  factory DownloadRegion.fromJson(Map<String, dynamic> json) {
    final rawPolygons = json['polygons'] as List<dynamic>? ?? [];
    final polygons = rawPolygons.map<List<List<double>>>((poly) {
      return (poly as List<dynamic>).map<List<double>>((vertex) {
        final value = vertex as List<dynamic>;
        return [
          (value[0] as num).toDouble(),
          (value[1] as num).toDouble(),
        ];
      }).toList();
    }).toList();

    return DownloadRegion(
      polygons: polygons,
      minZoom: json['minZoom'] as int? ?? 8,
      maxZoom: json['maxZoom'] as int? ?? 14,
    );
  }
}

class StyleInfo {
  final String hash;
  final String displayName;
  final String urlTemplate;
  final int tileCount;
  final int sizeBytes;
  final DownloadRegion? region;

  const StyleInfo({
    required this.hash,
    required this.displayName,
    required this.urlTemplate,
    this.tileCount = 0,
    this.sizeBytes = 0,
    this.region,
  });

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'displayName': displayName,
    'urlTemplate': urlTemplate,
    'tileCount': tileCount,
    'sizeBytes': sizeBytes,
    if (region != null) 'region': region!.toJson(),
  };

  factory StyleInfo.fromJson(Map<String, dynamic> json) => StyleInfo(
    hash: json['hash'] as String,
    displayName: json['displayName'] as String? ?? json['hash'] as String,
    urlTemplate: json['urlTemplate'] as String? ?? '',
    tileCount: json['tileCount'] as int? ?? 0,
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    region: json['region'] != null
        ? DownloadRegion.fromJson(json['region'] as Map<String, dynamic>)
        : null,
  );
}

class CachedTileCoord {
  final int z;
  final int x;
  final int y;

  const CachedTileCoord(this.z, this.x, this.y);

  Map<String, int> toJson() => {'z': z, 'x': x, 'y': y};

  factory CachedTileCoord.fromJson(Map<String, dynamic> json) => CachedTileCoord(
    json['z'] as int,
    json['x'] as int,
    json['y'] as int,
  );
}

class CachedTileData {
  final Uint8List bytes;
  final String? contentType;

  const CachedTileData({
    required this.bytes,
    required this.contentType,
  });
}

class _CachedTileLocation {
  final String relativePath;
  final String? contentType;

  const _CachedTileLocation({
    required this.relativePath,
    required this.contentType,
  });
}

class OfflineTileCacheService {
  OfflineTileCacheService._();

  static final instance = OfflineTileCacheService._();
  static const int _memoryCacheMaxEntries = 4096;
  static const int _memoryCacheMaxBytes = 64 * 1024 * 1024;

  final Map<String, Set<String>> _manifests = {};
  final Map<String, _CachedTileLocation> _tileLocationCache =
      <String, _CachedTileLocation>{};
  final LinkedHashMap<String, CachedTileData> _tileMemoryCache =
      LinkedHashMap<String, CachedTileData>();

  String? _baseDir;
  int _tileMemoryBytes = 0;

  AppDatabase get _db => DatabaseService().db;

  Future<String> get baseDir async {
    if (_baseDir != null) return _baseDir!;
    final docs = await getApplicationDocumentsDirectory();
    _baseDir = '${docs.path}/offline_tiles';
    return _baseDir!;
  }

  @visibleForTesting
  void setBaseDirForTesting(String path) {
    _baseDir = path;
  }

  @visibleForTesting
  void resetForTesting() {
    _baseDir = null;
    _manifests.clear();
    clearMemoryCacheForTesting();
  }

  @visibleForTesting
  void clearMemoryCacheForTesting() {
    _tileLocationCache.clear();
    _tileMemoryCache.clear();
    _tileMemoryBytes = 0;
  }

  String styleHashFromUrl(String urlTemplate) {
    final bytes = sha256.convert(urlTemplate.codeUnits).bytes;
    return bytes.take(6).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _tileDir(String base, String styleHash, int z, int x) {
    return '$base/$styleHash/$z/$x';
  }

  String _manifestPath(String base, String styleHash) {
    return '$base/$styleHash/manifest.txt';
  }

  static String _tileKey(int z, int x, int y) => '$z/$x/$y';

  Future<Set<String>> loadManifest(String styleHash) async {
    if (_manifests.containsKey(styleHash)) return _manifests[styleHash]!;

    var rows = await (_db.select(_db.offlineTileEntries)
          ..where((t) => t.styleHash.equals(styleHash)))
        .get();
    if (rows.isEmpty) {
      await _hydrateStyleFromDisk(styleHash);
      rows = await (_db.select(_db.offlineTileEntries)
            ..where((t) => t.styleHash.equals(styleHash)))
          .get();
    }

    final manifest = rows.map((row) => _tileKey(row.z, row.x, row.y)).toSet();
    _manifests[styleHash] = manifest;
    return manifest;
  }

  Future<CachedTileData?> getTileData(String styleHash, int z, int x, int y) async {
    final cacheKey = '$styleHash/${_tileKey(z, x, y)}';
    final cached = _tileMemoryCache.remove(cacheKey);
    if (cached != null) {
      _tileMemoryCache[cacheKey] = cached;
      return cached;
    }

    var location = _tileLocationCache[cacheKey];
    if (location == null) {
      final row = await _loadTileRow(styleHash, z, x, y);
      if (row == null) return null;
      if (row.relativePath == null || row.relativePath!.isEmpty) {
        await _deleteTileEntry(styleHash, z, x, y);
        return null;
      }
      location = _CachedTileLocation(
        relativePath: row.relativePath!,
        contentType: row.contentType,
      );
      _tileLocationCache[cacheKey] = location;
    }

    final base = await baseDir;
    final file = File('$base/${location.relativePath}');
    if (!await file.exists()) {
      await _deleteTileEntry(styleHash, z, x, y);
      return null;
    }

    final data = CachedTileData(
      bytes: await file.readAsBytes(),
      contentType: location.contentType,
    );
    _rememberTile(cacheKey, data);
    return data;
  }

  Future<Uint8List?> getRawTile(String styleHash, int z, int x, int y) async {
    final tile = await getTileData(styleHash, z, x, y);
    return tile?.bytes;
  }

  Future<bool> hasTile(String styleHash, int z, int x, int y) async {
    final cacheKey = '$styleHash/${_tileKey(z, x, y)}';
    if (_tileLocationCache.containsKey(cacheKey)) {
      _manifests[styleHash] ??= {};
      _manifests[styleHash]!.add(_tileKey(z, x, y));
      return true;
    }

    final row = await _loadTileRow(styleHash, z, x, y);
    if (row != null) {
      if (row.relativePath != null && row.relativePath!.isNotEmpty) {
        _tileLocationCache[cacheKey] = _CachedTileLocation(
          relativePath: row.relativePath!,
          contentType: row.contentType,
        );
      }
      _manifests[styleHash] ??= {};
      _manifests[styleHash]!.add(_tileKey(z, x, y));
      return true;
    }

    final manifest = await loadManifest(styleHash);
    return manifest.contains(_tileKey(z, x, y));
  }

  Future<void> putTile(
    String styleHash,
    int z,
    int x,
    int y,
    Uint8List bytes, {
    String? contentType,
    String? sourceUrl,
  }) async {
    final resolvedContentType = _normalizeContentType(contentType);
    final fileExtension = _fileExtensionForTile(
      contentType: resolvedContentType,
      sourceUrl: sourceUrl,
    );
    final relativePath = '$styleHash/$z/$x/$y.$fileExtension';
    final base = await baseDir;
    final dir = Directory(_tileDir(base, styleHash, z, x));
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('$base/$relativePath');
    await file.writeAsBytes(bytes, flush: true);
    await _upsertTileEntry(
      styleHash: styleHash,
      z: z,
      x: x,
      y: y,
      relativePath: relativePath,
      contentType: resolvedContentType,
      sizeBytes: bytes.length,
    );

    _manifests[styleHash] ??= {};
    _manifests[styleHash]!.add(_tileKey(z, x, y));
    await _writeManifest(base, styleHash, _manifests[styleHash]!);
    _rememberTile(
      '$styleHash/${_tileKey(z, x, y)}',
      CachedTileData(bytes: bytes, contentType: resolvedContentType),
    );
  }

  Future<void> putRawTile(
    String styleHash,
    int z,
    int x,
    int y,
    Uint8List bytes, {
    String? contentType,
  }) async {
    await putTile(
      styleHash,
      z,
      x,
      y,
      bytes,
      contentType: contentType,
    );
  }

  Future<void> saveStyleMeta(
    String styleHash, {
    required String displayName,
    required String urlTemplate,
    DownloadRegion? region,
  }) async {
    final base = await baseDir;
    final dir = Directory('$base/$styleHash');
    if (!await dir.exists()) await dir.create(recursive: true);

    final metaFile = File('$base/$styleHash/meta.json');
    final meta = <String, dynamic>{
      'displayName': displayName,
      'urlTemplate': urlTemplate,
    };

    if (region != null) {
      meta['region'] = region.toJson();
    } else if (await metaFile.exists()) {
      try {
        final existing = jsonDecode(await metaFile.readAsString());
        if (existing['region'] != null) {
          meta['region'] = existing['region'];
        }
      } catch (_) {}
    }

    await metaFile.writeAsString(jsonEncode(meta), flush: true);

    final existing = await ((_db.select(_db.offlineTileStyles)
          ..where((t) => t.styleHash.equals(styleHash)))
        .getSingleOrNull());
    await _db.into(_db.offlineTileStyles).insertOnConflictUpdate(
      OfflineTileStylesCompanion(
        styleHash: drift.Value(styleHash),
        displayName: drift.Value(displayName),
        urlTemplate: drift.Value(urlTemplate),
        regionJson: drift.Value(meta['region'] != null ? jsonEncode(meta['region']) : null),
        tileCount: drift.Value(existing?.tileCount ?? 0),
        sizeBytes: drift.Value(existing?.sizeBytes ?? 0),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<List<StyleInfo>> listStylesDetailed() async {
    var rows = await (_db.select(_db.offlineTileStyles)
          ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
        .get();
    if (rows.isEmpty) {
      await _hydrateAllStylesFromDisk();
      rows = await (_db.select(_db.offlineTileStyles)
            ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)]))
          .get();
    }

    return rows.map(_styleInfoFromRow).toList();
  }

  Future<List<String>> listStyles() async {
    final styles = await listStylesDetailed();
    return styles.map((style) => style.hash).toList();
  }

  Future<List<CachedTileCoord>> listTilesForStyle(String styleHash) async {
    var rows = await ((_db.select(_db.offlineTileEntries)
          ..where((t) => t.styleHash.equals(styleHash))
          ..orderBy([
            (t) => drift.OrderingTerm.asc(t.z),
            (t) => drift.OrderingTerm.asc(t.x),
            (t) => drift.OrderingTerm.asc(t.y),
          ]))
        .get());
    if (rows.isEmpty) {
      await _hydrateStyleFromDisk(styleHash);
      rows = await ((_db.select(_db.offlineTileEntries)
            ..where((t) => t.styleHash.equals(styleHash))
            ..orderBy([
              (t) => drift.OrderingTerm.asc(t.z),
              (t) => drift.OrderingTerm.asc(t.x),
              (t) => drift.OrderingTerm.asc(t.y),
            ]))
          .get());
    }

    return rows.map((row) => CachedTileCoord(row.z, row.x, row.y)).toList();
  }

  Future<void> deleteStyle(String styleHash) async {
    _manifests.remove(styleHash);
    _removeStyleFromMemory(styleHash);
    final base = await baseDir;
    final dir = Directory('$base/$styleHash');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await (_db.delete(_db.offlineTileEntries)..where((t) => t.styleHash.equals(styleHash))).go();
    await (_db.delete(_db.offlineTileStyles)..where((t) => t.styleHash.equals(styleHash))).go();
  }

  Future<int> getCacheSize() async {
    final result = await _db.customSelect(
      'SELECT COALESCE(SUM(size_bytes), 0) AS total FROM offline_tile_entries',
    ).getSingle();
    return result.read<int>('total');
  }

  Future<void> clearCache() async {
    _manifests.clear();
    _tileMemoryCache.clear();
    _tileMemoryBytes = 0;
    final base = await baseDir;
    final dir = Directory(base);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await _db.delete(_db.offlineTileEntries).go();
    await _db.delete(_db.offlineTileStyles).go();
  }

  StyleInfo _styleInfoFromRow(DbOfflineTileStyle row) {
    final region = row.regionJson == null
        ? null
        : DownloadRegion.fromJson(jsonDecode(row.regionJson!) as Map<String, dynamic>);
    return StyleInfo(
      hash: row.styleHash,
      displayName: row.displayName,
      urlTemplate: row.urlTemplate,
      tileCount: row.tileCount,
      sizeBytes: row.sizeBytes,
      region: region,
    );
  }

  Future<void> _hydrateAllStylesFromDisk() async {
    final base = await baseDir;
    final dir = Directory(base);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final styleHash = entity.path.split('/').last;
        await _hydrateStyleFromDisk(styleHash);
      }
    }
  }

  Future<void> _hydrateStyleFromDisk(String styleHash) async {
    final base = await baseDir;
    final styleDir = Directory('$base/$styleHash');
    if (!await styleDir.exists()) return;

    String displayName = styleHash;
    String urlTemplate = '';
    DownloadRegion? region;
    final metaFile = File('$base/$styleHash/meta.json');
    if (await metaFile.exists()) {
      try {
        final json = jsonDecode(await metaFile.readAsString());
        displayName = json['displayName'] as String? ?? styleHash;
        urlTemplate = json['urlTemplate'] as String? ?? '';
        if (json['region'] != null) {
          region = DownloadRegion.fromJson(json['region'] as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    final entries = <({int z, int x, int y, String relativePath, String? contentType, int sizeBytes})>[];
    await for (final entity in styleDir.list(recursive: true)) {
      if (entity is! File) continue;
      final relativePath = entity.path.replaceFirst('$base/', '');
      final segments = relativePath.split('/');
      if (segments.length != 4) continue;
      if (segments[3] == 'meta.json' || segments[3] == 'manifest.txt') continue;

      final z = int.tryParse(segments[1]);
      final x = int.tryParse(segments[2]);
      final ySegment = segments[3].split('.').first;
      final y = int.tryParse(ySegment);
      if (z == null || x == null || y == null) continue;

      entries.add((
        z: z,
        x: x,
        y: y,
        relativePath: relativePath,
        contentType: _contentTypeFromPath(relativePath),
        sizeBytes: await entity.length(),
      ));
    }

    await _db.transaction(() async {
      await (_db.delete(_db.offlineTileEntries)..where((t) => t.styleHash.equals(styleHash))).go();

      var totalSize = 0;
      for (final entry in entries) {
        totalSize += entry.sizeBytes;
        await _db.into(_db.offlineTileEntries).insert(
          OfflineTileEntriesCompanion.insert(
            styleHash: styleHash,
            z: entry.z,
            x: entry.x,
            y: entry.y,
            relativePath: drift.Value(entry.relativePath),
            contentType: drift.Value(entry.contentType),
            sizeBytes: entry.sizeBytes,
            cachedAt: DateTime.now(),
          ),
        );
      }

      await _db.into(_db.offlineTileStyles).insertOnConflictUpdate(
        OfflineTileStylesCompanion(
          styleHash: drift.Value(styleHash),
          displayName: drift.Value(displayName),
          urlTemplate: drift.Value(urlTemplate),
          regionJson: drift.Value(region == null ? null : jsonEncode(region.toJson())),
          tileCount: drift.Value(entries.length),
          sizeBytes: drift.Value(totalSize),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
    });

    _manifests[styleHash] = entries.map((entry) => _tileKey(entry.z, entry.x, entry.y)).toSet();
    for (final entry in entries) {
      _tileLocationCache['$styleHash/${_tileKey(entry.z, entry.x, entry.y)}'] =
          _CachedTileLocation(
        relativePath: entry.relativePath,
        contentType: entry.contentType,
      );
    }
    await _writeManifest(base, styleHash, _manifests[styleHash]!);
  }

  Future<void> _upsertTileEntry({
    required String styleHash,
    required int z,
    required int x,
    required int y,
    required String relativePath,
    required String? contentType,
    required int sizeBytes,
  }) async {
    final existingTile = await ((_db.select(_db.offlineTileEntries)
          ..where(
            (t) =>
                t.styleHash.equals(styleHash) &
                t.z.equals(z) &
                t.x.equals(x) &
                t.y.equals(y),
          ))
        .getSingleOrNull());
    final existingStyle = await ((_db.select(_db.offlineTileStyles)
          ..where((t) => t.styleHash.equals(styleHash)))
        .getSingleOrNull());

    if (existingTile != null) {
      final base = await baseDir;
      if (existingTile.relativePath != null && existingTile.relativePath != relativePath) {
        final oldFile = File('$base/${existingTile.relativePath!}');
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }
    }

    final tileCountDelta = existingTile == null ? 1 : 0;
    final sizeDelta = sizeBytes - (existingTile?.sizeBytes ?? 0);
    await _db.into(_db.offlineTileEntries).insertOnConflictUpdate(
      OfflineTileEntriesCompanion(
        id: existingTile == null ? const drift.Value.absent() : drift.Value(existingTile.id),
        styleHash: drift.Value(styleHash),
        z: drift.Value(z),
        x: drift.Value(x),
        y: drift.Value(y),
        relativePath: drift.Value(relativePath),
        contentType: drift.Value(contentType),
        sizeBytes: drift.Value(sizeBytes),
        cachedAt: drift.Value(DateTime.now()),
      ),
    );
    _tileLocationCache['$styleHash/${_tileKey(z, x, y)}'] = _CachedTileLocation(
      relativePath: relativePath,
      contentType: contentType,
    );

    await _db.into(_db.offlineTileStyles).insertOnConflictUpdate(
      OfflineTileStylesCompanion(
        styleHash: drift.Value(styleHash),
        displayName: drift.Value(existingStyle?.displayName ?? styleHash),
        urlTemplate: drift.Value(existingStyle?.urlTemplate ?? ''),
        regionJson: drift.Value(existingStyle?.regionJson),
        tileCount: drift.Value((existingStyle?.tileCount ?? 0) + tileCountDelta),
        sizeBytes: drift.Value((existingStyle?.sizeBytes ?? 0) + sizeDelta),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  Future<void> _deleteTileEntry(String styleHash, int z, int x, int y) async {
    final existingTile = await ((_db.select(_db.offlineTileEntries)
          ..where(
            (t) =>
                t.styleHash.equals(styleHash) &
                t.z.equals(z) &
                t.x.equals(x) &
                t.y.equals(y),
          ))
        .getSingleOrNull());
    if (existingTile == null) return;

    await (_db.delete(_db.offlineTileEntries)..where((t) => t.id.equals(existingTile.id))).go();

    final existingStyle = await ((_db.select(_db.offlineTileStyles)
          ..where((t) => t.styleHash.equals(styleHash)))
        .getSingleOrNull());
    if (existingStyle != null) {
      await _db.into(_db.offlineTileStyles).insertOnConflictUpdate(
        OfflineTileStylesCompanion(
          styleHash: drift.Value(styleHash),
          displayName: drift.Value(existingStyle.displayName),
          urlTemplate: drift.Value(existingStyle.urlTemplate),
          regionJson: drift.Value(existingStyle.regionJson),
          tileCount: drift.Value((existingStyle.tileCount - 1).clamp(0, existingStyle.tileCount)),
          sizeBytes: drift.Value((existingStyle.sizeBytes - existingTile.sizeBytes).clamp(0, existingStyle.sizeBytes)),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
    }

    _manifests[styleHash]?.remove(_tileKey(z, x, y));
    _tileLocationCache.remove('$styleHash/${_tileKey(z, x, y)}');
    final removed = _tileMemoryCache.remove('$styleHash/${_tileKey(z, x, y)}');
    if (removed != null) {
      _tileMemoryBytes -= removed.bytes.length;
    }
    final base = await baseDir;
    final manifest = _manifests[styleHash];
    if (manifest != null) {
      await _writeManifest(base, styleHash, manifest);
    }
  }

  Future<void> _writeManifest(
    String base,
    String styleHash,
    Set<String> manifest,
  ) async {
    final dir = Directory('$base/$styleHash');
    if (!await dir.exists()) await dir.create(recursive: true);
    await File(_manifestPath(base, styleHash)).writeAsString(
      manifest.join('\n'),
      flush: true,
    );
  }

  void _rememberTile(String key, CachedTileData data) {
    final existing = _tileMemoryCache.remove(key);
    if (existing != null) {
      _tileMemoryBytes -= existing.bytes.length;
    }
    _tileMemoryCache[key] = data;
    _tileMemoryBytes += data.bytes.length;

    while (_tileMemoryCache.length > _memoryCacheMaxEntries || _tileMemoryBytes > _memoryCacheMaxBytes) {
      final firstKey = _tileMemoryCache.keys.first;
      final removed = _tileMemoryCache.remove(firstKey);
      if (removed != null) {
        _tileMemoryBytes -= removed.bytes.length;
      }
    }
  }

  void _removeStyleFromMemory(String styleHash) {
    final prefix = '$styleHash/';
    _tileLocationCache.removeWhere((key, _) => key.startsWith(prefix));
    final keys = _tileMemoryCache.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      final removed = _tileMemoryCache.remove(key);
      if (removed != null) {
        _tileMemoryBytes -= removed.bytes.length;
      }
    }
  }

  String? _normalizeContentType(String? contentType) {
    if (contentType == null || contentType.isEmpty) return null;
    return contentType.split(';').first.trim().toLowerCase();
  }

  String _fileExtensionForTile({
    required String? contentType,
    required String? sourceUrl,
  }) {
    if (contentType != null) {
      switch (contentType) {
        case 'image/png':
          return 'png';
        case 'image/jpeg':
          return 'jpg';
        case 'image/webp':
          return 'webp';
        case 'image/avif':
          return 'avif';
      }
    }

    final uri = sourceUrl == null ? null : Uri.tryParse(sourceUrl);
    final segment = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
    final match = RegExp(r'\.(png|jpg|jpeg|webp|avif)$', caseSensitive: false).firstMatch(segment);
    final extension = match?.group(1)?.toLowerCase();
    if (extension == 'jpeg') return 'jpg';
    return extension ?? 'tile';
  }

  String? _contentTypeFromPath(String relativePath) {
    if (relativePath.endsWith('.png')) return 'image/png';
    if (relativePath.endsWith('.jpg') || relativePath.endsWith('.jpeg')) return 'image/jpeg';
    if (relativePath.endsWith('.webp')) return 'image/webp';
    if (relativePath.endsWith('.avif')) return 'image/avif';
    return null;
  }

  Future<DbOfflineTileEntry?> _loadTileRow(String styleHash, int z, int x, int y) async {
    var row = await ((_db.select(_db.offlineTileEntries)
          ..where(
            (t) =>
                t.styleHash.equals(styleHash) &
                t.z.equals(z) &
                t.x.equals(x) &
                t.y.equals(y),
          ))
        .getSingleOrNull());
    if (row == null) {
      await _hydrateStyleFromDisk(styleHash);
      row = await ((_db.select(_db.offlineTileEntries)
            ..where(
              (t) =>
                  t.styleHash.equals(styleHash) &
                  t.z.equals(z) &
                  t.x.equals(x) &
                  t.y.equals(y),
            ))
          .getSingleOrNull());
    }
    return row;
  }
}

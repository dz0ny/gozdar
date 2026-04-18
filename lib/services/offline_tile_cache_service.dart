import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:path_provider/path_provider.dart';

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

class OfflineTileCacheService {
  OfflineTileCacheService._();

  static final instance = OfflineTileCacheService._();

  String? _baseDir;
  final Map<String, Set<String>> _manifests = {};

  Future<String> get baseDir async {
    if (_baseDir != null) return _baseDir!;
    final docs = await getApplicationDocumentsDirectory();
    _baseDir = '${docs.path}/offline_tiles';
    return _baseDir!;
  }

  String styleHashFromUrl(String urlTemplate) {
    final bytes = sha256.convert(urlTemplate.codeUnits).bytes;
    return bytes.take(6).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _tilePath(String base, String styleHash, int z, int x, int y) {
    return '$base/$styleHash/$z/$x/$y.avif';
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

    final base = await baseDir;
    final file = File(_manifestPath(base, styleHash));
    final Set<String> manifest;

    if (await file.exists()) {
      final lines = await file.readAsLines();
      manifest = lines.where((line) => line.isNotEmpty).toSet();
    } else {
      manifest = {};
      final styleDir = Directory('$base/$styleHash');
      if (await styleDir.exists()) {
        final avifPattern = RegExp(r'/(\d+)/(\d+)/(\d+)\.avif$');
        await for (final entity in styleDir.list(recursive: true)) {
          if (entity is! File) continue;
          final match = avifPattern.firstMatch(entity.path);
          if (match != null) {
            manifest.add('${match.group(1)}/${match.group(2)}/${match.group(3)}');
          }
        }
        await _writeManifest(base, styleHash, manifest);
      }
    }

    _manifests[styleHash] = manifest;
    return manifest;
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

  Future<void> _addToManifest(String base, String styleHash, String key) async {
    _manifests[styleHash] ??= {};
    if (_manifests[styleHash]!.add(key)) {
      final file = File(_manifestPath(base, styleHash));
      await file.writeAsString('$key\n', mode: FileMode.append, flush: true);
    }
  }

  Future<Uint8List?> getRawTile(String styleHash, int z, int x, int y) async {
    final base = await baseDir;
    final file = File(_tilePath(base, styleHash, z, x, y));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<bool> hasTile(String styleHash, int z, int x, int y) async {
    final manifest = await loadManifest(styleHash);
    return manifest.contains(_tileKey(z, x, y));
  }

  Future<Uint8List?> getTileAsPng(String styleHash, int z, int x, int y) async {
    final avifBytes = await getRawTile(styleHash, z, x, y);
    if (avifBytes == null) return null;
    return _avifToPng(avifBytes);
  }

  Future<void> putTile(
    String styleHash,
    int z,
    int x,
    int y,
    Uint8List pngBytes,
  ) async {
    final base = await baseDir;
    final dir = Directory(_tileDir(base, styleHash, z, x));
    if (!await dir.exists()) await dir.create(recursive: true);

    final avifBytes = await _pngToAvif(pngBytes);
    await File(_tilePath(base, styleHash, z, x, y)).writeAsBytes(
      avifBytes ?? pngBytes,
      flush: true,
    );

    await _addToManifest(base, styleHash, _tileKey(z, x, y));
  }

  Future<void> putRawTile(
    String styleHash,
    int z,
    int x,
    int y,
    Uint8List avifBytes,
  ) async {
    final base = await baseDir;
    final dir = Directory(_tileDir(base, styleHash, z, x));
    if (!await dir.exists()) await dir.create(recursive: true);
    await File(_tilePath(base, styleHash, z, x, y)).writeAsBytes(
      avifBytes,
      flush: true,
    );
    await _addToManifest(base, styleHash, _tileKey(z, x, y));
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
  }

  Future<List<StyleInfo>> listStylesDetailed() async {
    final base = await baseDir;
    final dir = Directory(base);
    if (!await dir.exists()) return [];

    final results = <StyleInfo>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final hash = entity.path.split('/').last;

      String displayName = hash;
      String urlTemplate = '';
      DownloadRegion? region;
      final metaFile = File('${entity.path}/meta.json');
      if (await metaFile.exists()) {
        try {
          final json = jsonDecode(await metaFile.readAsString());
          displayName = json['displayName'] as String? ?? hash;
          urlTemplate = json['urlTemplate'] as String? ?? '';
          if (json['region'] != null) {
            region = DownloadRegion.fromJson(
              json['region'] as Map<String, dynamic>,
            );
          }
        } catch (_) {}
      }

      var tileCount = 0;
      var sizeBytes = 0;
      await for (final file in entity.list(recursive: true)) {
        if (file is File && file.path.endsWith('.avif')) {
          tileCount++;
          sizeBytes += await file.length();
        }
      }

      results.add(
        StyleInfo(
          hash: hash,
          displayName: displayName,
          urlTemplate: urlTemplate,
          tileCount: tileCount,
          sizeBytes: sizeBytes,
          region: region,
        ),
      );
    }

    return results;
  }

  Future<List<String>> listStyles() async {
    final base = await baseDir;
    final dir = Directory(base);
    if (!await dir.exists()) return [];

    final styles = <String>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        styles.add(entity.path.split('/').last);
      }
    }
    return styles;
  }

  Future<List<CachedTileCoord>> listTilesForStyle(String styleHash) async {
    final base = await baseDir;
    final styleDir = Directory('$base/$styleHash');
    if (!await styleDir.exists()) return [];

    final tiles = <CachedTileCoord>[];
    final avifPattern = RegExp(r'/(\d+)/(\d+)/(\d+)\.avif$');

    await for (final entity in styleDir.list(recursive: true)) {
      if (entity is! File) continue;
      final match = avifPattern.firstMatch(entity.path);
      if (match != null) {
        tiles.add(
          CachedTileCoord(
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
            int.parse(match.group(3)!),
          ),
        );
      }
    }
    return tiles;
  }

  Future<void> deleteStyle(String styleHash) async {
    _manifests.remove(styleHash);
    final base = await baseDir;
    final dir = Directory('$base/$styleHash');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<int> getCacheSize() async {
    final base = await baseDir;
    final dir = Directory(base);
    if (!await dir.exists()) return 0;

    var totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  Future<void> clearCache() async {
    _manifests.clear();
    final base = await baseDir;
    final dir = Directory(base);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<Uint8List?> _pngToAvif(Uint8List pngBytes) async {
    try {
      final avif = await encodeAvif(
        pngBytes,
        maxThreads: 2,
        maxQuantizer: 40,
        minQuantizer: 25,
        maxQuantizerAlpha: 63,
        minQuantizerAlpha: 63,
        speed: 6,
        keepExif: false,
      );
      if (avif.isEmpty) return null;
      return avif;
    } catch (e) {
      debugPrint('[OfflineTileCache] AVIF encode error: $e');
      return null;
    }
  }

  static Future<Uint8List?> _avifToPng(Uint8List avifBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(avifBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[OfflineTileCache] AVIF decode error: $e');
      return null;
    }
  }
}

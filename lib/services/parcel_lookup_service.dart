import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'cadastral_service.dart';

/// Thrown when a download is cancelled by the caller.
class ParcelDownloadCancelled implements Exception {
  const ParcelDownloadCancelled();
}

/// One downloadable region from the R2 `regions.json` manifest.
class ParcelRegion {
  final String code;
  final String name;
  final String file;
  final int? bytes;
  final int? rows;

  const ParcelRegion({
    required this.code,
    required this.name,
    required this.file,
    this.bytes,
    this.rows,
  });

  factory ParcelRegion.fromJson(Map<String, dynamic> j) => ParcelRegion(
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        file: (j['file'] ?? '').toString(),
        bytes: (j['bytes'] as num?)?.toInt(),
        rows: (j['rows'] as num?)?.toInt(),
      );

  /// Approximate size in MB, or null when unknown.
  double? get sizeMb => bytes != null ? bytes! / (1024 * 1024) : null;
}

/// Result of importing/downloading a parcels database file.
class ParcelImportResult {
  final int rows;
  const ParcelImportResult(this.rows);
}

/// One open region database.
class _RegionDb {
  final Database db;
  final String path;
  final String fileName;
  final String? region;
  final String? dataDate;
  final String? source; // 'imported' | 'downloaded'
  final int rowCount;
  final bool hasRtree;

  _RegionDb({
    required this.db,
    required this.path,
    required this.fileName,
    required this.region,
    required this.dataDate,
    required this.source,
    required this.rowCount,
    required this.hasRtree,
  });
}

/// Read-only, fully offline lookup of cadastral parcel geometry from one or more
/// region databases (`parcels-<region>.sqlite`, built by
/// `tools/parcels/convert.py` from the GURS `SI.GURS.KN:PARCELE` shapefile).
///
/// Multiple regions can be loaded at once — every `parcels*.sqlite` in the app
/// support directory is opened and queries fan out across all of them (regions
/// don't overlap, so a tap resolves in exactly one). When any database is loaded
/// the app renders/identifies the cadastral layer locally instead of the online
/// WMS proxy. Owners are resolved separately by [OwnerLookupService].
class ParcelLookupService {
  ParcelLookupService._();
  static final ParcelLookupService instance = ParcelLookupService._();
  factory ParcelLookupService() => instance;

  /// Geometry blob format version emitted by the converter.
  static const _blobVersion = 1;

  /// R2 host serving the offline databases.
  static const r2BaseUrl = 'https://gozdar-kataster.dz0ny.dev';
  static const regionsManifestUrl = '$r2BaseUrl/regions.json';

  final List<_RegionDb> _dbs = [];

  /// LRU cache of decoded parcels keyed by `eid` so re-querying overlapping
  /// bounds while panning reuses already-decoded geometry instead of re-reading
  /// the poly blob. Insertion-ordered ([LinkedHashMap]); the oldest entry is
  /// evicted once [_decodeCacheCap] is reached. Cleared whenever databases are
  /// loaded/unloaded/replaced so stale geometry can't survive a region swap.
  static const _decodeCacheCap = 8000;
  final LinkedHashMap<String, CadastralParcel> _decodeCache =
      LinkedHashMap<String, CadastralParcel>();

  void _clearDecodeCache() => _decodeCache.clear();

  /// Whether at least one offline parcels database is loaded.
  bool get isAvailable => _dbs.isNotEmpty;

  /// Total parcels across all loaded regions.
  int get rowCount => _dbs.fold(0, (sum, d) => sum + d.rowCount);

  /// Names of the loaded regions (falls back to the file name), sorted.
  List<String> get loadedRegions {
    final names = _dbs
        .map((d) => d.region ?? d.fileName.replaceFirst('.sqlite', ''))
        .toList()
      ..sort();
    return names;
  }

  /// File names of the loaded databases (e.g. `parcels-gorenjska.sqlite`).
  Set<String> get loadedFiles => _dbs.map((d) => d.fileName).toSet();

  /// The GURS source date of the loaded data (they share one), or null.
  String? get dataDate => _dbs.isNotEmpty ? _dbs.first.dataDate : null;

  Future<String> _dirPath() async =>
      (await getApplicationSupportDirectory()).path;

  String _join(String dir, String name) => '$dir${Platform.pathSeparator}$name';

  String _baseName(String path) => path.split(Platform.pathSeparator).last;

  /// Total size in bytes of all loaded database files, or null when none.
  Future<int?> fileSizeBytes() async {
    if (_dbs.isEmpty) return null;
    var total = 0;
    for (final d in _dbs) {
      final f = File(d.path);
      if (await f.exists()) total += await f.length();
    }
    return total;
  }

  /// Open every `parcels*.sqlite` found in app storage. Safe on every app start.
  Future<void> init() async {
    try {
      final dir = Directory(await _dirPath());
      if (!dir.existsSync()) return;
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = _baseName(entity.path);
        if (name.startsWith('parcels') && name.endsWith('.sqlite')) {
          try {
            _dbs.add(_openDb(entity.path));
          } catch (e) {
            debugPrint('ParcelLookupService.init open($name) failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('ParcelLookupService.init failed: $e');
    }
  }

  _RegionDb _openDb(String path) {
    // A new region is being added — drop decoded geometry so a re-query can't
    // return parcels from before the loaded set changed.
    _clearDecodeCache();
    final db = sqlite3.open(path);
    final hasTable = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='parcels'",
    );
    if (hasTable.isEmpty) {
      db.close();
      throw const FormatException('Datoteka ni veljavna baza parcel.');
    }
    return _RegionDb(
      db: db,
      path: path,
      fileName: _baseName(path),
      region: _readMeta(db, 'region'),
      dataDate: _readMeta(db, 'date'),
      source: _readSource(path),
      rowCount: _readRowCount(db),
      hasRtree: _detectRtree(db),
    );
  }

  /// Close + drop the in-memory handle for [path] if currently open.
  void _dropOpen(String path) {
    _clearDecodeCache();
    _dbs.removeWhere((d) {
      if (d.path == path) {
        d.db.close();
        return true;
      }
      return false;
    });
  }

  String? _readSource(String path) {
    try {
      final f = File('$path.src');
      if (f.existsSync()) {
        final v = f.readAsStringSync().trim();
        return v.isNotEmpty ? v : null;
      }
    } catch (_) {}
    return null;
  }

  void _writeSource(String path, String src) {
    try {
      File('$path.src').writeAsStringSync(src);
    } catch (e) {
      debugPrint('ParcelLookupService._writeSource failed: $e');
    }
  }

  String? _readMeta(Database db, String key) {
    try {
      final r = db.select('SELECT v FROM meta WHERE k=?', [key]);
      if (r.isNotEmpty) {
        final v = r.first['v']?.toString();
        return (v != null && v.isNotEmpty) ? v : null;
      }
    } catch (_) {}
    return null;
  }

  /// Fetch the list of downloadable regions from a `regions.json` manifest.
  static Future<List<ParcelRegion>> fetchRegions(String manifestUrl) async {
    final resp = await http.get(Uri.parse(manifestUrl));
    if (resp.statusCode != 200) {
      throw FormatException(
          'Seznama regij ni bilo mogoče naložiti (HTTP ${resp.statusCode}).');
    }
    final data = jsonDecode(resp.body);
    final list = (data is Map ? data['regions'] : data) as List<dynamic>;
    return list
        .map((e) => ParcelRegion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  bool _detectRtree(Database db) {
    try {
      final r = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='parcels_rtree'",
      );
      return r.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  int _readRowCount(Database db) {
    try {
      final meta = db.select("SELECT v FROM meta WHERE k='rows'");
      if (meta.isNotEmpty) {
        return int.tryParse(meta.first['v'].toString()) ?? 0;
      }
    } catch (_) {
      // meta table missing — fall back to a COUNT.
    }
    final c = db.select('SELECT COUNT(*) AS n FROM parcels');
    return c.isEmpty ? 0 : (c.first['n'] as int);
  }

  /// Target file name for a picked file: keep `parcels*.sqlite` names as-is,
  /// otherwise namespace it so it is discovered and doesn't clash with regions.
  String _importTargetName(String sourcePath) {
    final base = _baseName(sourcePath);
    if (base.startsWith('parcels') && base.endsWith('.sqlite')) return base;
    final stem = base.replaceAll(RegExp(r'\.[^.]*$'), '');
    final safe = stem.replaceAll(RegExp(r'[^0-9A-Za-z_-]+'), '-');
    return 'parcels-import-$safe.sqlite';
  }

  /// Import (copy) a picked `.sqlite` file into the app and open it, adding it to
  /// the loaded set (does not remove other regions).
  Future<ParcelImportResult> importFromFile(String sourcePath) async {
    final target = _join(await _dirPath(), _importTargetName(sourcePath));
    _dropOpen(target);
    await _deleteDbFiles(target);
    await File(sourcePath).copy(target);
    try {
      _writeSource(target, 'imported');
      final opened = _openDb(target);
      _dbs.add(opened);
      return ParcelImportResult(opened.rowCount);
    } on FormatException {
      await _deleteDbFiles(target);
      throw const FormatException('Izbrana datoteka ni baza parcel.');
    } catch (e) {
      await _deleteDbFiles(target);
      rethrow;
    }
  }

  /// Stream-download a region database from [url] into [fileName] and open it,
  /// adding it to the loaded set (other regions stay loaded). Reports progress
  /// via [onProgress]; throw [ParcelDownloadCancelled] from [isCancelled] to
  /// abort. Writes to a `.part` file and only swaps in on success.
  Future<ParcelImportResult> downloadAndOpen(
    String url, {
    required String fileName,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final target = _join(await _dirPath(), fileName);
    final part = File('$target.part');
    if (await part.exists()) await part.delete();

    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) {
        throw FormatException('Prenos ni uspel (HTTP ${response.statusCode}).');
      }
      final total = response.contentLength;
      var received = 0;
      final sink = part.openWrite();
      try {
        await for (final chunk in response.stream) {
          if (isCancelled?.call() ?? false) {
            throw const ParcelDownloadCancelled();
          }
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }

      // Swap into place and (re)open, replacing this region if already loaded.
      _dropOpen(target);
      await _deleteDbFiles(target);
      await part.rename(target);
      try {
        _writeSource(target, 'downloaded');
        final opened = _openDb(target);
        _dbs.add(opened);
        return ParcelImportResult(opened.rowCount);
      } on FormatException {
        await _deleteDbFiles(target);
        throw const FormatException('Prenesena datoteka ni baza parcel.');
      }
    } finally {
      client.close();
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
    }
  }

  /// Remove all loaded region databases.
  Future<void> removeAll() async {
    _clearDecodeCache();
    final paths = _dbs.map((d) => d.path).toList();
    for (final d in _dbs) {
      d.db.close();
    }
    _dbs.clear();
    for (final p in paths) {
      await _deleteDbFiles(p);
    }
  }

  /// Remove loaded databases matching [onlySource] (`'imported'`/`'downloaded'`),
  /// or all when null. Returns how many were removed.
  Future<int> removeBySource(String? onlySource) async {
    _clearDecodeCache();
    final toRemove = _dbs
        .where((d) => onlySource == null || d.source == onlySource)
        .toList();
    for (final d in toRemove) {
      d.db.close();
      _dbs.remove(d);
      await _deleteDbFiles(d.path);
    }
    return toRemove.length;
  }

  Future<void> _deleteDbFiles(String path) async {
    // NOTE: never include '.part' here — _deleteDbFiles(target) runs in the
    // download path right before `<target>.part` is renamed into place.
    for (final suffix in ['', '-wal', '-shm', '-journal', '.src']) {
      final file = File('$path$suffix');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('ParcelLookupService._deleteDbFiles($suffix) failed: $e');
        }
      }
    }
  }

  // --- Queries -------------------------------------------------------------

  /// All parcels whose bounding box intersects the viewport, across every loaded
  /// region. Capped at [limit] total.
  List<CadastralParcel> parcelsInBounds({
    required double west,
    required double east,
    required double south,
    required double north,
    int limit = 4000,
  }) {
    if (_dbs.isEmpty) return const [];
    final out = <CadastralParcel>[];
    for (final r in _dbs) {
      if (out.length >= limit) break;
      _appendBounds(r, west, east, south, north, limit - out.length, out);
    }
    return out;
  }

  void _appendBounds(_RegionDb r, double w, double e, double s, double n,
      int limit, List<CadastralParcel> out) {
    try {
      final ResultSet rows;
      if (r.hasRtree) {
        rows = r.db.select(
          'SELECT p.sifko, p.parcela, p.area, p.eid, p.poly '
          'FROM parcels_rtree x JOIN parcels p ON p.id = x.id '
          'WHERE x.max_lon >= ? AND x.min_lon <= ? '
          'AND x.max_lat >= ? AND x.min_lat <= ? LIMIT ?',
          [w, e, s, n, limit],
        );
      } else {
        rows = r.db.select(
          'SELECT sifko, parcela, area, eid, poly FROM parcels '
          'WHERE max_lon >= ? AND min_lon <= ? '
          'AND max_lat >= ? AND min_lat <= ? LIMIT ?',
          [w, e, s, n, limit],
        );
      }
      for (final row in rows) {
        final p = _rowToParcel(row);
        if (p != null) out.add(p);
      }
    } catch (e) {
      debugPrint('ParcelLookupService._appendBounds failed: $e');
    }
  }

  /// The parcel containing [point], or null. Searches each loaded region until a
  /// containing polygon is found.
  CadastralParcel? parcelAt(LatLng point) {
    final lon = point.longitude, lat = point.latitude;
    for (final r in _dbs) {
      final hit = _atFrom(r, lon, lat);
      if (hit != null) return hit;
    }
    return null;
  }

  CadastralParcel? _atFrom(_RegionDb r, double lon, double lat) {
    try {
      final ResultSet rows;
      if (r.hasRtree) {
        rows = r.db.select(
          'SELECT p.sifko, p.parcela, p.area, p.eid, p.poly '
          'FROM parcels_rtree x JOIN parcels p ON p.id = x.id '
          'WHERE x.min_lon <= ? AND x.max_lon >= ? '
          'AND x.min_lat <= ? AND x.max_lat >= ?',
          [lon, lon, lat, lat],
        );
      } else {
        rows = r.db.select(
          'SELECT sifko, parcela, area, eid, poly FROM parcels '
          'WHERE min_lon <= ? AND max_lon >= ? '
          'AND min_lat <= ? AND max_lat >= ?',
          [lon, lon, lat, lat],
        );
      }
      for (final row in rows) {
        final rings = _decodeRings(row['poly'] as Uint8List);
        if (rings.isEmpty) continue;
        if (_pointInRing(lon, lat, rings.first)) {
          return _parcelFrom(row, rings.first);
        }
      }
    } catch (e) {
      debugPrint('ParcelLookupService._atFrom failed: $e');
    }
    return null;
  }

  CadastralParcel? _rowToParcel(Row row) {
    final eid = (row['eid'] ?? '').toString();
    if (eid.isNotEmpty) {
      final cached = _decodeCache.remove(eid);
      if (cached != null) {
        // Re-insert to mark as most-recently-used.
        _decodeCache[eid] = cached;
        return cached;
      }
    }
    final rings = _decodeRings(row['poly'] as Uint8List);
    if (rings.isEmpty) return null;
    final parcel = _parcelFrom(row, rings.first);
    if (eid.isNotEmpty) {
      _decodeCache[eid] = parcel;
      if (_decodeCache.length > _decodeCacheCap) {
        _decodeCache.remove(_decodeCache.keys.first);
      }
    }
    return parcel;
  }

  CadastralParcel _parcelFrom(Row row, List<LatLng> outerRing) {
    return CadastralParcel(
      id: (row['eid'] ?? '').toString(),
      cadastralMunicipality: (row['sifko'] as int?) ?? 0,
      parcelNumber: (row['parcela'] ?? '').toString(),
      area: (row['area'] as num?)?.toDouble() ?? 0.0,
      polygon: outerRing,
    );
  }

  /// Decode the geometry blob into one or more rings of WGS84 points.
  /// Layout (little-endian): u8 version, u32 ringCount, then per ring
  /// u32 pointCount followed by pointCount * (i32 lon_e7, i32 lat_e7).
  List<List<LatLng>> _decodeRings(Uint8List bytes) {
    if (bytes.length < 5) return const [];
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    final version = data.getUint8(offset);
    offset += 1;
    if (version != _blobVersion) return const [];
    final ringCount = data.getUint32(offset, Endian.little);
    offset += 4;
    final rings = <List<LatLng>>[];
    for (var r = 0; r < ringCount; r++) {
      if (offset + 4 > bytes.length) break;
      final pointCount = data.getUint32(offset, Endian.little);
      offset += 4;
      final ring = <LatLng>[];
      for (var p = 0; p < pointCount; p++) {
        if (offset + 8 > bytes.length) break;
        final lonE7 = data.getInt32(offset, Endian.little);
        final latE7 = data.getInt32(offset + 4, Endian.little);
        offset += 8;
        ring.add(LatLng(latE7 / 1e7, lonE7 / 1e7));
      }
      if (ring.length >= 3) rings.add(ring);
    }
    return rings;
  }

  /// Ray-casting point-in-polygon test against a single ring.
  bool _pointInRing(double lon, double lat, List<LatLng> ring) {
    var inside = false;
    final n = ring.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = ring[i].longitude, yi = ring[i].latitude;
      final xj = ring[j].longitude, yj = ring[j].latitude;
      final intersects = ((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }
}

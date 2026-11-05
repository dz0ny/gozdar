import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:sqlite3/sqlite3.dart';

import 'cadastral_service.dart';
import 'owner_lookup_service.dart';
import 'parcel_lookup_service.dart';
import 'public_parcel_settings.dart';

/// Parcels of a map viewport, with the public-owner category of those that
/// have one (keyed by [CadastralParcel.id]).
class MapParcels {
  const MapParcels(this.parcels, this.categories, {this.truncated = false});

  final List<CadastralParcel> parcels;
  final Map<String, PublicOwnerCategory> categories;

  /// More parcels were in the bounds than the limit: these are the ones on
  /// screen and nearest its centre, the bounds are not covered in full.
  final bool truncated;
}

/// Loads the offline kataster parcels of a viewport on a background isolate:
/// the bounds query, the geometry decoding and the public-owner lookups (one
/// query per parcel) run there, so a dense area never stalls a frame. The
/// isolate keeps its own connections to the files [ParcelLookupService] and
/// [OwnerLookupService] have open, and reopens them when those change.
class MapParcelsWorker {
  MapParcelsWorker._();
  static final MapParcelsWorker instance = MapParcelsWorker._();

  Future<SendPort>? _worker;
  final _replies = ReceivePort();
  final _pending = <int, Completer<_Reply>>{};
  int _nextId = 0;

  /// Decoded parcels by `eid`, so re-querying an overlapping viewport reuses
  /// the [LatLng] lists; cleared when the open files change.
  static const _decodedCap = 8000;
  final _decoded = <String, CadastralParcel>{}; // insertion-ordered
  String? _decodedFor;

  /// Up to [limit] parcels inside [bounds] from the loaded regions, plus
  /// their public-owner categories when [categories] is set. When there are
  /// more, the ones inside [visible] (the screen; defaults to [bounds]) come
  /// first, then the nearest to its centre, so a dense area never leaves the
  /// screen empty while drawing parcels beyond it.
  Future<MapParcels> parcelsInBounds(
    LatLngBounds bounds, {
    required bool categories,
    int limit = 4000,
    LatLngBounds? visible,
  }) async {
    final screen = visible ?? bounds;
    final regions = ParcelLookupService.instance.regionFiles;
    final publics = categories
        ? OwnerLookupService.instance.publicDbFiles
        : const <({String path, int id})>[];
    final config = _Config(
      regions: [for (final r in regions) (path: r.path, hasRtree: r.hasRtree)],
      publics: [for (final f in publics) f.path],
      key: [
        for (final r in regions) r.id,
        '|',
        for (final f in publics) f.id,
      ].join(','),
    );
    if (config.regions.isEmpty) return const MapParcels([], {});

    final send = await (_worker ??= _start());
    final id = _nextId++;
    final reply = Completer<_Reply>();
    _pending[id] = reply;
    send.send(
      _Request(
        id: id,
        config: config,
        west: bounds.west,
        east: bounds.east,
        south: bounds.south,
        north: bounds.north,
        visibleWest: screen.west,
        visibleEast: screen.east,
        visibleSouth: screen.south,
        visibleNorth: screen.north,
        limit: limit,
        categories: categories,
      ),
    );
    final r = await reply.future;
    if (r.error != null) throw StateError(r.error!);

    if (_decodedFor != config.key) {
      _decoded.clear();
      _decodedFor = config.key;
    }
    final parcels = <CadastralParcel>[];
    final cats = <String, PublicOwnerCategory>{};
    for (var i = 0; i < r.eids.length; i++) {
      final parcel = _parcel(r, i);
      parcels.add(parcel);
      final c = r.categories?[i] ?? -1;
      if (c >= 0) cats[parcel.id] = PublicOwnerCategory.values[c];
    }
    return MapParcels(parcels, cats, truncated: r.truncated);
  }

  CadastralParcel _parcel(_Reply r, int i) {
    final eid = r.eids[i];
    final cached = eid.isEmpty ? null : _decoded.remove(eid);
    if (cached != null) return _decoded[eid] = cached; // most recently used
    final ring = r.rings[i];
    final parcel = CadastralParcel(
      id: eid,
      cadastralMunicipality: r.sifkos[i],
      parcelNumber: r.parcele[i],
      area: r.areas[i],
      polygon: [
        for (var p = 0; p + 1 < ring.length; p += 2)
          LatLng(ring[p + 1] / 1e7, ring[p] / 1e7),
      ],
    );
    if (eid.isNotEmpty) {
      _decoded[eid] = parcel;
      if (_decoded.length > _decodedCap) _decoded.remove(_decoded.keys.first);
    }
    return parcel;
  }

  Future<SendPort> _start() async {
    final ready = Completer<SendPort>();
    _replies.listen((msg) {
      if (msg is SendPort) {
        ready.complete(msg);
      } else if (msg is _Reply) {
        _pending.remove(msg.id)?.complete(msg);
      }
    });
    await Isolate.spawn(
      _workerMain,
      _replies.sendPort,
      debugName: 'MapParcelsWorker',
    );
    return ready.future;
  }
}

/// The files to read. [key] also changes when a file is reopened at the
/// same path, so the worker drops its stale connection.
class _Config {
  const _Config({
    required this.regions,
    required this.publics,
    required this.key,
  });

  final List<({String path, bool hasRtree})> regions;
  final List<String> publics;
  final String key;
}

class _Request {
  const _Request({
    required this.id,
    required this.config,
    required this.west,
    required this.east,
    required this.south,
    required this.north,
    required this.visibleWest,
    required this.visibleEast,
    required this.visibleSouth,
    required this.visibleNorth,
    required this.limit,
    required this.categories,
  });

  final int id;
  final _Config config;
  final double west, east, south, north;
  final double visibleWest, visibleEast, visibleSouth, visibleNorth;
  final int limit;
  final bool categories;
}

/// Column-wise parcels: rings hold the outer ring as lon/lat E7 pairs.
/// [categories] holds a [PublicOwnerCategory] index or -1 per parcel.
class _Reply {
  const _Reply({
    required this.id,
    this.eids = const [],
    this.sifkos = const [],
    this.parcele = const [],
    this.areas = const [],
    this.rings = const [],
    this.categories,
    this.truncated = false,
    this.error,
  });

  final int id;
  final bool truncated;
  final List<String> eids;
  final List<int> sifkos;
  final List<String> parcele;
  final List<double> areas;
  final List<Int32List> rings;
  final Int8List? categories;
  final String? error;
}

void _workerMain(SendPort toMain) {
  final inbox = ReceivePort();
  toMain.send(inbox.sendPort);
  final state = _WorkerState();
  inbox.listen((msg) {
    final request = msg as _Request;
    try {
      toMain.send(state.handle(request));
    } catch (e) {
      toMain.send(_Reply(id: request.id, error: '$e'));
    }
  });
}

class _WorkerState {
  String? _key;
  final _regions = <({Database db, bool hasRtree})>[];
  final _publicQueries = <PreparedStatement>[];
  final _publicDbs = <Database>[];

  /// Category per "sifko/parcela" (-1: none); valid for [_key].
  final _categories = <String, int>{};

  /// Ordering of a row: 0 for parcels on screen, 1 for the rest, then the
  /// squared distance of the bounding-box centre from the screen centre
  /// (longitude scaled to the latitude), so `ORDER BY k` fills from the
  /// screen centre out.
  static const _orderKey =
      '(CASE WHEN {t}max_lon >= ?5 AND {t}min_lon <= ?6 '
      'AND {t}max_lat >= ?7 AND {t}min_lat <= ?8 THEN 0 ELSE 1 END) * 1e6 + '
      '(({t}min_lon + {t}max_lon) / 2 - ?9) * (({t}min_lon + {t}max_lon) / 2 - ?9) * ?11 + '
      '(({t}min_lat + {t}max_lat) / 2 - ?10) * (({t}min_lat + {t}max_lat) / 2 - ?10)';

  static final _rtreeSql =
      'SELECT p.sifko, p.parcela, p.area, p.eid, p.poly, '
      '${_orderKey.replaceAll('{t}', 'x.')} AS k '
      'FROM parcels_rtree x JOIN parcels p ON p.id = x.id '
      'WHERE x.max_lon >= ?1 AND x.min_lon <= ?2 '
      'AND x.max_lat >= ?3 AND x.min_lat <= ?4 ORDER BY k LIMIT ?12';

  static final _plainSql =
      'SELECT sifko, parcela, area, eid, poly, '
      '${_orderKey.replaceAll('{t}', '')} AS k FROM parcels '
      'WHERE max_lon >= ?1 AND min_lon <= ?2 '
      'AND max_lat >= ?3 AND min_lat <= ?4 ORDER BY k LIMIT ?12';

  _Reply handle(_Request r) {
    _configure(r.config);
    final centreLat = (r.visibleSouth + r.visibleNorth) / 2;
    final cosLat = math.cos(centreLat * math.pi / 180);
    final params = [
      r.west, r.east, r.south, r.north, // ?1-?4: the bounds
      r.visibleWest, r.visibleEast, r.visibleSouth, r.visibleNorth, // ?5-?8
      (r.visibleWest + r.visibleEast) / 2, centreLat, // ?9, ?10: the centre
      cosLat * cosLat, // ?11: squared longitude scale
      r.limit + 1, // ?12: one more tells whether the limit cut it off
    ];
    // Each region gives its own nearest; merged by the same key so a border
    // between regions does not favour the first file.
    final found = <({double k, Row row})>[];
    for (final region in _regions) {
      try {
        final rows = region.db.select(
          region.hasRtree ? _rtreeSql : _plainSql,
          params,
        );
        for (final row in rows) {
          found.add((k: (row['k'] as num).toDouble(), row: row));
        }
      } catch (e) {
        debugPrint('MapParcelsWorker bounds query failed: $e');
      }
    }
    found.sort((a, b) => a.k.compareTo(b.k));
    final truncated = found.length > r.limit;

    final eids = <String>[];
    final sifkos = <int>[];
    final parcele = <String>[];
    final areas = <double>[];
    final rings = <Int32List>[];
    for (final f in found.take(r.limit)) {
      final row = f.row;
      final ring = _outerRing(row['poly'] as Uint8List);
      if (ring == null) continue;
      eids.add((row['eid'] ?? '').toString());
      sifkos.add((row['sifko'] as int?) ?? 0);
      parcele.add((row['parcela'] ?? '').toString());
      areas.add((row['area'] as num?)?.toDouble() ?? 0.0);
      rings.add(ring);
    }

    Int8List? categories;
    if (r.categories && _publicQueries.isNotEmpty) {
      categories = Int8List(eids.length);
      for (var i = 0; i < eids.length; i++) {
        categories[i] = _category(sifkos[i], parcele[i].trim());
      }
    }
    return _Reply(
      id: r.id,
      eids: eids,
      sifkos: sifkos,
      parcele: parcele,
      areas: areas,
      rings: rings,
      categories: categories,
      truncated: truncated,
    );
  }

  int _category(int sifko, String parcela) {
    if (parcela.isEmpty) return -1;
    return _categories.putIfAbsent('$sifko/$parcela', () {
      try {
        final c = OwnerLookupService.categoryOfRows([
          for (final q in _publicQueries) ...q.select([sifko, parcela]),
        ]);
        return c?.index ?? -1;
      } catch (e) {
        debugPrint('MapParcelsWorker category failed: $e');
        return -1;
      }
    });
  }

  void _configure(_Config config) {
    if (config.key == _key) return;
    _close();
    for (final region in config.regions) {
      try {
        _regions.add((db: _open(region.path), hasRtree: region.hasRtree));
      } catch (e) {
        debugPrint('MapParcelsWorker could not open ${region.path}: $e');
      }
    }
    for (final path in config.publics) {
      try {
        final db = _open(path);
        _publicDbs.add(db);
        _publicQueries.add(db.prepare(OwnerLookupService.publicRowsSql));
      } catch (e) {
        debugPrint('MapParcelsWorker could not open $path: $e');
      }
    }
    _key = config.key;
  }

  /// Opened read-write but query-only: a read-only open fails for WAL-mode
  /// databases (see [OwnerLookupService]).
  static Database _open(String path) => sqlite3.open(path)
    ..execute('PRAGMA query_only = 1')
    ..execute('PRAGMA busy_timeout = 5000');

  void _close() {
    for (final q in _publicQueries) {
      q.close();
    }
    for (final db in [..._publicDbs, for (final r in _regions) r.db]) {
      db.close();
    }
    _publicQueries.clear();
    _publicDbs.clear();
    _regions.clear();
    _categories.clear();
    _key = null;
  }

  /// The first ring with at least 3 points of a `poly` blob (see
  /// [ParcelLookupService]), as lon/lat E7 pairs; null when there is none.
  static Int32List? _outerRing(Uint8List bytes) {
    if (bytes.length < 5) return null;
    final data = ByteData.sublistView(bytes);
    if (data.getUint8(0) != ParcelLookupService.blobVersion) return null;
    final ringCount = data.getUint32(1, Endian.little);
    var offset = 5;
    for (var r = 0; r < ringCount; r++) {
      if (offset + 4 > bytes.length) break;
      final pointCount = data.getUint32(offset, Endian.little);
      offset += 4;
      final available = (bytes.length - offset) ~/ 8;
      final points = pointCount < available ? pointCount : available;
      if (points >= 3) {
        final ring = Int32List(points * 2);
        for (var i = 0; i < points * 2; i++) {
          ring[i] = data.getInt32(offset + i * 4, Endian.little);
        }
        return ring;
      }
      offset += pointCount * 8;
    }
    return null;
  }
}

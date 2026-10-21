import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// One katastrska občina (KO): GURS code, name and a coarse outer boundary.
class KoInfo {
  final int sifko;
  final String name;
  final List<List<LatLng>> rings;
  final double minLon, minLat, maxLon, maxLat;

  /// Name folded for matching (uppercase, no Slovenian diacritics).
  final String folded;

  KoInfo({
    required this.sifko,
    required this.name,
    required this.rings,
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  }) : folded = KoLocator.fold(name);

  /// "BABNO POLJE (1651)".
  String get label => '$name ($sifko)';

  @override
  bool operator ==(Object other) => other is KoInfo && other.sifko == sifko;

  @override
  int get hashCode => sifko.hashCode;
}

/// Offline lookup of cadastral municipalities from the bundled
/// `assets/ko_index.json` (built by `tools/parcels/build_ko_index.py`).
///
/// Answers "which KO is this point in" and powers KO-name autocomplete without
/// any database or network. Boundaries are simplified (~50 m), so exact parcel
/// data is preferred for the point lookup when it is loaded.
class KoLocator {
  KoLocator._();
  static final KoLocator instance = KoLocator._();

  List<KoInfo>? _kos;
  Map<int, KoInfo> _bySifko = const {};

  bool get isLoaded => _kos != null;
  List<KoInfo> get all => _kos ?? const [];

  /// Load + parse the bundled index (once).
  Future<void> ensureLoaded() async {
    if (_kos != null) return;
    try {
      final raw = await rootBundle.loadString('assets/ko_index.json');
      _set(await compute(_parse, raw));
    } catch (e) {
      debugPrint('KoLocator.ensureLoaded failed: $e');
      _set(const []);
    }
  }

  @visibleForTesting
  void loadForTesting(String json) => _set(_parse(json));

  void _set(List<KoInfo> kos) {
    _kos = kos;
    _bySifko = {for (final k in kos) k.sifko: k};
  }

  static List<KoInfo> _parse(String raw) {
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final out = <KoInfo>[];
    for (final e in list) {
      final rings = <List<LatLng>>[];
      var mnLon = double.infinity, mnLat = double.infinity;
      var mxLon = -double.infinity, mxLat = -double.infinity;
      for (final r in (e['r'] as List)) {
        final pts = <LatLng>[];
        for (final c in (r as List)) {
          final lon = (c[0] as num) / 1e5, lat = (c[1] as num) / 1e5;
          pts.add(LatLng(lat.toDouble(), lon.toDouble()));
          if (lon < mnLon) mnLon = lon.toDouble();
          if (lon > mxLon) mxLon = lon.toDouble();
          if (lat < mnLat) mnLat = lat.toDouble();
          if (lat > mxLat) mxLat = lat.toDouble();
        }
        if (pts.length >= 3) rings.add(pts);
      }
      out.add(KoInfo(
        sifko: (e['s'] as num).toInt(),
        name: (e['n'] ?? '').toString(),
        rings: rings,
        minLon: mnLon,
        minLat: mnLat,
        maxLon: mxLon,
        maxLat: mxLat,
      ));
    }
    return out;
  }

  /// Uppercases and folds Slovenian/Croatian letters to ASCII, so "sentjur",
  /// "Šentjur" and "ŠENTJUR" all compare equal.
  static String fold(String s) {
    var out = s.toUpperCase();
    const folds = {'Č': 'C', 'Ć': 'C', 'Š': 'S', 'Ž': 'Z', 'Đ': 'D'};
    folds.forEach((from, to) => out = out.replaceAll(from, to));
    return out;
  }

  KoInfo? bySifko(int? sifko) => sifko == null ? null : _bySifko[sifko];

  /// The KO containing [point]. Falls back to the closest boundary vertex
  /// within roughly 300 m, to absorb the simplified borders.
  KoInfo? koAt(LatLng point) {
    final kos = _kos;
    if (kos == null) return null;
    final lon = point.longitude, lat = point.latitude;
    for (final k in kos) {
      if (lon < k.minLon || lon > k.maxLon || lat < k.minLat || lat > k.maxLat) {
        continue;
      }
      for (final ring in k.rings) {
        if (_inRing(lon, lat, ring)) return k;
      }
    }
    const tol = 0.003;
    KoInfo? best;
    var bestD = tol * tol;
    for (final k in kos) {
      if (lon < k.minLon - tol || lon > k.maxLon + tol ||
          lat < k.minLat - tol || lat > k.maxLat + tol) {
        continue;
      }
      for (final ring in k.rings) {
        for (final p in ring) {
          final dx = p.longitude - lon, dy = p.latitude - lat;
          final d = dx * dx + dy * dy;
          if (d < bestD) {
            bestD = d;
            best = k;
          }
        }
      }
    }
    return best;
  }

  /// KOs whose name (any word prefix, then substring) or code matches [query],
  /// best matches first. Case- and diacritic-insensitive.
  List<KoInfo> search(String query, {int limit = 6}) {
    final q = fold(query.trim());
    final kos = _kos;
    if (q.isEmpty || kos == null) return const [];
    final scored = <(int, KoInfo)>[];
    final numeric = int.tryParse(q) != null;
    for (final k in kos) {
      int? score;
      if (numeric) {
        final code = k.sifko.toString();
        if (code == q) {
          score = 0;
        } else if (code.startsWith(q)) {
          score = 3;
        }
      } else if (k.folded == q) {
        score = 0;
      } else if (k.folded.startsWith(q)) {
        score = 1;
      } else if (k.folded.split(RegExp(r'[\s-]+')).any((w) => w.startsWith(q))) {
        score = 2;
      } else if (q.length >= 3 && k.folded.contains(q)) {
        score = 4;
      }
      if (score != null) scored.add((score, k));
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      final l = a.$2.name.length.compareTo(b.$2.name.length);
      return l != 0 ? l : a.$2.name.compareTo(b.$2.name);
    });
    return [for (final s in scored.take(limit)) s.$2];
  }

  static bool _inRing(double lon, double lat, List<LatLng> ring) {
    var inside = false;
    final n = ring.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = ring[i].longitude, yi = ring[i].latitude;
      final xj = ring[j].longitude, yj = ring[j].latitude;
      if (((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }
}

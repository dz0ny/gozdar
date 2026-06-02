import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// One statistical region (boundary polygons + name/code) from the bundled
/// `assets/regije.geojson` (GURS RPE, the same file used to split the parcels).
class RegionInfo {
  final String name;
  final String code;
  final List<List<LatLng>> rings;
  final double minLon, minLat, maxLon, maxLat;

  const RegionInfo({
    required this.name,
    required this.code,
    required this.rings,
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  });
}

/// Resolves a point to its Slovenian statistical region, so the map can offer to
/// download the region's parcels when the user pans into it.
class RegionLocator {
  RegionLocator._();
  static final RegionLocator instance = RegionLocator._();

  List<RegionInfo>? _regions;

  bool get isLoaded => _regions != null;

  /// Load + parse the bundled region boundaries (once). Cheap (~26 KB).
  Future<void> ensureLoaded() async {
    if (_regions != null) return;
    try {
      final raw = await rootBundle.loadString('assets/regije.geojson');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final feats = (data['features'] as List).cast<dynamic>();
      final out = <RegionInfo>[];
      for (final f in feats) {
        final feat = f as Map<String, dynamic>;
        final props = (feat['properties'] as Map?) ?? const {};
        final name = (props['name'] ?? '').toString();
        final code = (props['code'] ?? '').toString();
        final rings = _ringsFromGeometry(feat['geometry'] as Map<String, dynamic>);
        if (rings.isEmpty) continue;
        var mnLon = double.infinity, mnLat = double.infinity;
        var mxLon = -double.infinity, mxLat = -double.infinity;
        for (final ring in rings) {
          for (final p in ring) {
            if (p.longitude < mnLon) mnLon = p.longitude;
            if (p.longitude > mxLon) mxLon = p.longitude;
            if (p.latitude < mnLat) mnLat = p.latitude;
            if (p.latitude > mxLat) mxLat = p.latitude;
          }
        }
        out.add(RegionInfo(
          name: name,
          code: code,
          rings: rings,
          minLon: mnLon,
          minLat: mnLat,
          maxLon: mxLon,
          maxLat: mxLat,
        ));
      }
      _regions = out;
    } catch (_) {
      _regions = const [];
    }
  }

  /// The region containing [point], or null. Returns nearest-by-containment
  /// (regions don't overlap).
  RegionInfo? regionForPoint(LatLng point) {
    final regions = _regions;
    if (regions == null) return null;
    final lon = point.longitude, lat = point.latitude;
    for (final r in regions) {
      if (lon < r.minLon || lon > r.maxLon || lat < r.minLat || lat > r.maxLat) {
        continue;
      }
      var inside = false;
      for (final ring in r.rings) {
        if (_pointInRing(lon, lat, ring)) inside = !inside;
      }
      if (inside) return r;
    }
    return null;
  }

  static List<List<LatLng>> _ringsFromGeometry(Map<String, dynamic> geom) {
    final type = geom['type'];
    final coords = geom['coordinates'] as List;
    final polys = <dynamic>[];
    if (type == 'Polygon') {
      polys.add(coords);
    } else if (type == 'MultiPolygon') {
      polys.addAll(coords);
    }
    final rings = <List<LatLng>>[];
    for (final poly in polys) {
      for (final ring in (poly as List)) {
        final pts = <LatLng>[];
        for (final c in (ring as List)) {
          pts.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
        }
        if (pts.length >= 3) rings.add(pts);
      }
    }
    return rings;
  }

  static bool _pointInRing(double lon, double lat, List<LatLng> ring) {
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

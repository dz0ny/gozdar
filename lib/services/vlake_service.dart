import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// A single Vlake (forest skid-road) polyline with a precomputed bounding box
/// for fast viewport culling.
class VlakeLine {
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;
  final List<LatLng> points;

  const VlakeLine(
    this.minLat,
    this.minLng,
    this.maxLat,
    this.maxLng,
    this.points,
  );
}

/// Loads the embedded Vlake overlay (`assets/vlake.bin`, produced by
/// `tool/build_vlake.dart`) and serves viewport-culled subsets for rendering.
///
/// The data (~78k polylines) is loaded lazily the first time the overlay is
/// enabled, parsed off the UI isolate, and kept in memory for the session.
class VlakeService {
  VlakeService._();
  static final VlakeService instance = VlakeService._();
  factory VlakeService() => instance;

  static const _assetPath = 'assets/vlake.bin';

  List<VlakeLine>? _lines;
  Future<void>? _loading;

  bool get isLoaded => _lines != null;
  int get count => _lines?.length ?? 0;

  /// Load and parse the asset once. Concurrent callers share the same future.
  Future<void> ensureLoaded() {
    if (_lines != null) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(_assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      _lines = await compute(_parseVlake, bytes);
    } catch (e) {
      debugPrint('VlakeService load failed: $e');
      _lines = const [];
    } finally {
      _loading = null;
    }
  }

  /// Lines whose bounding box intersects the given bounds, capped at [limit] to
  /// bound the number of polylines handed to the renderer.
  List<VlakeLine> linesInBounds(
    double south,
    double west,
    double north,
    double east, {
    int limit = 6000,
  }) {
    final lines = _lines;
    if (lines == null) return const [];
    final result = <VlakeLine>[];
    for (final l in lines) {
      final outside = l.maxLat < south ||
          l.minLat > north ||
          l.maxLng < west ||
          l.minLng > east;
      if (outside) continue;
      result.add(l);
      if (result.length >= limit) break;
    }
    return result;
  }
}

const _magic = 0x564C4B31; // "VLK1"

/// Top-level parser run via [compute] in a background isolate.
List<VlakeLine> _parseVlake(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var off = 0;
  if (data.lengthInBytes < 8 ||
      data.getUint32(off, Endian.little) != _magic) {
    return const [];
  }
  off += 4;
  final count = data.getUint32(off, Endian.little);
  off += 4;

  final lines = <VlakeLine>[];
  for (var i = 0; i < count; i++) {
    final n = data.getUint32(off, Endian.little);
    off += 4;
    if (n == 0) continue;
    final points = List<LatLng>.filled(n, const LatLng(0, 0));
    var minLat = 90.0, minLng = 180.0, maxLat = -90.0, maxLng = -180.0;
    for (var j = 0; j < n; j++) {
      final lat = data.getFloat32(off, Endian.little);
      final lng = data.getFloat32(off + 4, Endian.little);
      off += 8;
      points[j] = LatLng(lat, lng);
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    lines.add(VlakeLine(minLat, minLng, maxLat, maxLng, points));
  }
  return lines;
}

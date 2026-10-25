import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Metadata of one drone photo, read from the DJI XMP block and JPEG header.
class DronePhoto {
  final File file;
  final LatLng position;

  /// Height above take-off point in metres (DJI RelativeAltitude).
  final double relativeAltitudeM;

  /// Camera heading, degrees clockwise from north.
  final double headingDeg;

  /// Camera pitch; -90 = straight down.
  final double pitchDeg;
  final int width;
  final int height;

  const DronePhoto({
    required this.file,
    required this.position,
    required this.relativeAltitudeM,
    required this.headingDeg,
    required this.pitchDeg,
    required this.width,
    required this.height,
  });

  bool get isNadir => pitchDeg <= -80;
}

/// Ground geometry assumptions for the quick mosaic.
class PhotoFootprintOptions {
  /// Ground length of the long image side, as a multiple of the height.
  /// A 24 mm lens (35 mm equivalent) gives 36 / 24 = 1.5, as in OpenSfM.
  final double footprintPerMetre;

  /// Fraction of each photo (centre part) that the mosaic uses.
  /// The middle has the least distortion and hides most seams.
  final double keep;

  const PhotoFootprintOptions({this.footprintPerMetre = 1.5, this.keep = 0.6});
}

/// Result of [DronePhotoService.readAll].
class PhotoScan {
  final List<DronePhoto> inside;
  final int outside;
  final int unreadable;
  final int notNadir;

  const PhotoScan({
    required this.inside,
    required this.outside,
    required this.unreadable,
    required this.notNadir,
  });

  int get total => inside.length + outside + unreadable + notNadir;
}

class DronePhotoService {
  DronePhotoService._();
  static final DronePhotoService instance = DronePhotoService._();

  static const _headerBytes = 256 * 1024;
  static const _earthR = 6378137.0;

  static final _xmpTag = RegExp(
    r'drone-dji:(\w+)(?:\s*=\s*"([^"]*)"|>([^<]*)<)',
  );

  /// Reads photo metadata from the first bytes of [file]. Returns null when
  /// the file has no usable DJI position (non-DJI, stripped, not a JPEG).
  Future<DronePhoto?> readMeta(File file) async {
    final Uint8List head;
    final raf = await file.open();
    try {
      head = await raf.read(_headerBytes);
    } finally {
      await raf.close();
    }
    return parseMeta(file, head);
  }

  /// Parses [head] (start of a JPEG). Exposed for tests.
  DronePhoto? parseMeta(File file, List<int> head) {
    final text = String.fromCharCodes(head); // latin1: XMP is ASCII
    final tags = <String, String>{};
    for (final m in _xmpTag.allMatches(text)) {
      tags.putIfAbsent(m.group(1)!, () => (m.group(2) ?? m.group(3))!.trim());
    }
    double? num(String key) => double.tryParse(tags[key] ?? '');

    final lat = num('GpsLatitude');
    // DJI spelled it "GpsLongtitude" on older aircraft.
    final lon = num('GpsLongitude') ?? num('GpsLongtitude');
    if (lat == null || lon == null) return null;
    if (lat == 0 && lon == 0) return null;
    final size = _jpegSize(head);
    if (size == null) return null;

    return DronePhoto(
      file: file,
      position: LatLng(lat, lon),
      relativeAltitudeM: num('RelativeAltitude') ?? 0,
      headingDeg: num('GimbalYawDegree') ?? num('FlightYawDegree') ?? 0,
      pitchDeg: num('GimbalPitchDegree') ?? -90,
      width: size.$1,
      height: size.$2,
    );
  }

  /// Width and height from the first SOF marker, or null.
  (int, int)? _jpegSize(List<int> b) {
    if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = b[i + 1];
      if (marker == 0xFF) {
        i++;
        continue;
      }
      if (marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD7) || marker == 1) {
        i += 2;
        continue;
      }
      final len = (b[i + 2] << 8) | b[i + 3];
      final isSof =
          marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
      if (isSof) {
        final h = (b[i + 5] << 8) | b[i + 6];
        final w = (b[i + 7] << 8) | b[i + 8];
        return (w, h);
      }
      i += 2 + len;
    }
    return null;
  }

  /// Ground width and height (metres) of the kept central part of [photo].
  (double, double) keptSize(DronePhoto photo, PhotoFootprintOptions options) {
    final long = photo.relativeAltitudeM * options.footprintPerMetre;
    final landscape = photo.width >= photo.height;
    final ratio = landscape
        ? photo.height / photo.width
        : photo.width / photo.height;
    return (
      (landscape ? long : long * ratio) * options.keep,
      (landscape ? long * ratio : long) * options.keep,
    );
  }

  /// Corners of the kept (central) part of [photo]'s footprint in local metres
  /// (x east, y north) relative to [origin].
  List<(double, double)> footprintCorners(
    DronePhoto photo,
    LatLng origin,
    PhotoFootprintOptions options,
  ) {
    final (cx, cy) = toLocal(photo.position, origin);
    final (w, h) = keptSize(photo, options);
    // Image axes: "up" = heading, "right" = heading + 90°.
    final th = photo.headingDeg * math.pi / 180;
    final upX = math.sin(th), upY = math.cos(th);
    final rtX = math.cos(th), rtY = -math.sin(th);
    (double, double) corner(double sx, double sy) => (
      cx + rtX * sx * w / 2 + upX * sy * h / 2,
      cy + rtY * sx * w / 2 + upY * sy * h / 2,
    );
    return [corner(-1, 1), corner(1, 1), corner(1, -1), corner(-1, -1)];
  }

  /// Reads all [files] and keeps nadir photos whose kept footprint touches
  /// [polygon]. Everything else is counted and skipped.
  Future<PhotoScan> readAll(
    List<File> files,
    List<LatLng> polygon, {
    PhotoFootprintOptions options = const PhotoFootprintOptions(),
    void Function(int done, int total)? onProgress,
  }) async {
    final origin = _centroid(polygon);
    final poly = [for (final p in polygon) toLocal(p, origin)];
    final inside = <DronePhoto>[];
    var outside = 0, unreadable = 0, notNadir = 0;
    for (var i = 0; i < files.length; i++) {
      DronePhoto? meta;
      try {
        meta = await readMeta(files[i]);
      } catch (_) {
        meta = null;
      }
      if (meta == null) {
        unreadable++;
      } else if (!meta.isNadir) {
        notNadir++;
      } else if (polygonTouches(poly, footprintCorners(meta, origin, options))) {
        inside.add(meta);
      } else {
        outside++;
      }
      onProgress?.call(i + 1, files.length);
    }
    inside.sort((a, b) => a.file.path.compareTo(b.file.path));
    return PhotoScan(
      inside: inside,
      outside: outside,
      unreadable: unreadable,
      notNadir: notNadir,
    );
  }

  LatLng _centroid(List<LatLng> pts) => LatLng(
    pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length,
    pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length,
  );

  /// WGS84 to local metres (x east, y north) around [origin].
  (double, double) toLocal(LatLng p, LatLng origin) {
    final cosLat = math.cos(origin.latitude * math.pi / 180);
    return (
      (p.longitude - origin.longitude) * math.pi / 180 * _earthR * cosLat,
      (p.latitude - origin.latitude) * math.pi / 180 * _earthR,
    );
  }

  /// True when [rect] (4 corners) and the simple [poly] overlap.
  bool polygonTouches(
    List<(double, double)> poly,
    List<(double, double)> rect,
  ) {
    if (poly.length < 3) return false;
    for (final p in poly) {
      if (_inside(rect, p)) return true;
    }
    for (final c in rect) {
      if (_inside(poly, c)) return true;
    }
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      for (var j = 0; j < 4; j++) {
        if (_segmentsCross(a, b, rect[j], rect[(j + 1) % 4])) return true;
      }
    }
    return false;
  }

  bool _inside(List<(double, double)> poly, (double, double) p) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final (xi, yi) = poly[i];
      final (xj, yj) = poly[j];
      if ((yi > p.$2) != (yj > p.$2) &&
          p.$1 < (xj - xi) * (p.$2 - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  bool _segmentsCross(
    (double, double) a,
    (double, double) b,
    (double, double) c,
    (double, double) d,
  ) {
    double cross((double, double) o, (double, double) p, (double, double) q) =>
        (p.$1 - o.$1) * (q.$2 - o.$2) - (p.$2 - o.$2) * (q.$1 - o.$1);
    final d1 = cross(a, b, c), d2 = cross(a, b, d);
    final d3 = cross(c, d, a), d4 = cross(c, d, b);
    return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
  }
}

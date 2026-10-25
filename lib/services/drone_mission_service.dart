import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';

/// Parameters for a photogrammetry-style survey flight over a parcel.
class DroneMissionOptions {
  /// Flight height above take-off point, metres.
  final double altitudeM;

  /// Ground speed, m/s.
  final double speedMs;

  /// Overlap between neighbouring flight lines, 0..1.
  final double sideOverlap;

  /// Direction of the flight lines in degrees clockwise from north.
  final double headingDeg;

  /// Approximate ground width covered by one photo, as a multiple of height.
  /// Conservative value for a ~24 mm-equivalent lens in 4:3.
  final double footprintPerMetre;

  const DroneMissionOptions({
    this.altitudeM = 60,
    this.speedMs = 5,
    this.sideOverlap = 0.7,
    this.headingDeg = 0,
    this.footprintPerMetre = 1.2,
  });

  double get lineSpacingM => altitudeM * footprintPerMetre * (1 - sideOverlap);
}

/// A waypoint of the generated flight plan (WGS84).
class MissionWaypoint {
  final LatLng position;
  const MissionWaypoint(this.position);
}

/// Builds DJI WPML waypoint missions (KMZ) that can be loaded in DJI Fly.
class DroneMissionService {
  DroneMissionService._();
  static final DroneMissionService instance = DroneMissionService._();

  static const _earthR = 6371008.8;

  /// Lawnmower waypoints covering [polygon], clipped to it.
  List<MissionWaypoint> planGrid(
    List<LatLng> polygon,
    DroneMissionOptions options,
  ) {
    if (polygon.length < 3) return [];
    final origin = LatLng(
      polygon.map((p) => p.latitude).reduce((a, b) => a + b) / polygon.length,
      polygon.map((p) => p.longitude).reduce((a, b) => a + b) / polygon.length,
    );
    final cosLat = math.cos(origin.latitude * math.pi / 180);

    // Local metres (x east, y north), then rotated so flight lines run along x.
    final theta = options.headingDeg * math.pi / 180;
    final c = math.cos(theta), s = math.sin(theta);
    // Heading h (clockwise from north): line direction = (sin h, cos h).
    // Rotate so that direction maps to +x.
    (double, double) toLocal(LatLng p) {
      final x = (p.longitude - origin.longitude) * math.pi / 180 * _earthR * cosLat;
      final y = (p.latitude - origin.latitude) * math.pi / 180 * _earthR;
      return (x * s + y * c, x * c - y * s);
    }

    LatLng fromLocal(double u, double v) {
      final x = u * s + v * c;
      final y = u * c - v * s;
      return LatLng(
        origin.latitude + y / _earthR * 180 / math.pi,
        origin.longitude + x / (_earthR * cosLat) * 180 / math.pi,
      );
    }

    final pts = polygon.map(toLocal).toList();
    final minV = pts.map((p) => p.$2).reduce(math.min);
    final maxV = pts.map((p) => p.$2).reduce(math.max);
    final spacing = options.lineSpacingM;
    if (spacing <= 0) return [];

    final result = <MissionWaypoint>[];
    var forward = true;
    // Start half a spacing inside the bbox so the first line is covered.
    for (var v = minV + spacing / 2; v <= maxV + 1e-6; v += spacing) {
      final xs = <double>[];
      for (var i = 0; i < pts.length; i++) {
        final a = pts[i], b = pts[(i + 1) % pts.length];
        if ((a.$2 <= v && b.$2 > v) || (b.$2 <= v && a.$2 > v)) {
          final t = (v - a.$2) / (b.$2 - a.$2);
          xs.add(a.$1 + t * (b.$1 - a.$1));
        }
      }
      xs.sort();
      // Even-odd fill: take each inside interval, serpentine order.
      final segments = <(double, double)>[];
      for (var i = 0; i + 1 < xs.length; i += 2) {
        segments.add((xs[i], xs[i + 1]));
      }
      final ordered = forward ? segments : segments.reversed.toList();
      for (final seg in ordered) {
        final a = forward ? seg.$1 : seg.$2;
        final b = forward ? seg.$2 : seg.$1;
        result.add(MissionWaypoint(fromLocal(a, v)));
        result.add(MissionWaypoint(fromLocal(b, v)));
      }
      if (segments.isNotEmpty) forward = !forward;
    }
    return result;
  }

  /// Total flight path length in metres.
  double pathLengthM(List<MissionWaypoint> wps) {
    const d = Distance();
    var sum = 0.0;
    for (var i = 1; i < wps.length; i++) {
      sum += d(wps[i - 1].position, wps[i].position);
    }
    return sum;
  }

  /// Encodes the mission as a DJI WPML KMZ (wpmz/template.kml + waylines.wpml).
  Uint8List buildKmz({
    required String name,
    required List<MissionWaypoint> waypoints,
    DroneMissionOptions options = const DroneMissionOptions(),
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final duration = options.speedMs > 0
        ? pathLengthM(waypoints) / options.speedMs
        : 0.0;
    final distance = pathLengthM(waypoints);

    String placemarks({required bool executable}) {
      final b = StringBuffer();
      for (var i = 0; i < waypoints.length; i++) {
        final p = waypoints[i].position;
        b.writeln('''
      <Placemark>
        <Point><coordinates>${p.longitude.toStringAsFixed(8)},${p.latitude.toStringAsFixed(8)}</coordinates></Point>
        <wpml:index>$i</wpml:index>
        <wpml:${executable ? 'executeHeight' : 'ellipsoidHeight'}>${options.altitudeM}</wpml:${executable ? 'executeHeight' : 'ellipsoidHeight'}>
        <wpml:${executable ? 'waypointSpeed' : 'height'}>${executable ? options.speedMs : options.altitudeM}</wpml:${executable ? 'waypointSpeed' : 'height'}>
        <wpml:useGlobalHeight>${executable ? 0 : 1}</wpml:useGlobalHeight>
        <wpml:useGlobalSpeed>${executable ? 0 : 1}</wpml:useGlobalSpeed>
        <wpml:useGlobalHeadingParam>1</wpml:useGlobalHeadingParam>
        <wpml:useGlobalTurnParam>1</wpml:useGlobalTurnParam>
      </Placemark>''');
      }
      return b.toString();
    }

    final missionConfig = '''
    <wpml:missionConfig>
      <wpml:flyToWaylineMode>safely</wpml:flyToWaylineMode>
      <wpml:finishAction>goHome</wpml:finishAction>
      <wpml:exitOnRCLost>executeLostAction</wpml:exitOnRCLost>
      <wpml:executeRCLostAction>goBack</wpml:executeRCLostAction>
      <wpml:globalTransitionalSpeed>${options.speedMs}</wpml:globalTransitionalSpeed>
    </wpml:missionConfig>''';

    final template = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:wpml="http://www.dji.com/wpmz/1.0.6">
  <Document>
    <wpml:author>Gozdar</wpml:author>
    <wpml:createTime>$now</wpml:createTime>
    <wpml:updateTime>$now</wpml:updateTime>
$missionConfig
    <Folder>
      <wpml:templateType>waypoint</wpml:templateType>
      <wpml:templateId>0</wpml:templateId>
      <wpml:waylineCoordinateSysParam>
        <wpml:coordinateMode>WGS84</wpml:coordinateMode>
        <wpml:heightMode>relativeToStartPoint</wpml:heightMode>
      </wpml:waylineCoordinateSysParam>
      <wpml:autoFlightSpeed>${options.speedMs}</wpml:autoFlightSpeed>
      <wpml:globalHeight>${options.altitudeM}</wpml:globalHeight>
      <wpml:globalWaypointTurnMode>toPointAndStopWithDiscontinuityCurvature</wpml:globalWaypointTurnMode>
      <wpml:globalUseStraightLine>1</wpml:globalUseStraightLine>
${placemarks(executable: false)}
    </Folder>
  </Document>
</kml>''';

    final waylines = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:wpml="http://www.dji.com/wpmz/1.0.6">
  <Document>
$missionConfig
    <Folder>
      <wpml:templateId>0</wpml:templateId>
      <wpml:executeHeightMode>relativeToStartPoint</wpml:executeHeightMode>
      <wpml:waylineId>0</wpml:waylineId>
      <wpml:distance>${distance.toStringAsFixed(1)}</wpml:distance>
      <wpml:duration>${duration.toStringAsFixed(1)}</wpml:duration>
      <wpml:autoFlightSpeed>${options.speedMs}</wpml:autoFlightSpeed>
${placemarks(executable: true)}
    </Folder>
  </Document>
</kml>''';

    ArchiveFile file(String path, String content) {
      final data = utf8.encode(content);
      return ArchiveFile(path, data.length, data);
    }

    final archive = Archive()
      ..addFile(file('wpmz/template.kml', template))
      ..addFile(file('wpmz/waylines.wpml', waylines));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }
}

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/drone_mission_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // ~200 m x ~200 m square near Ljubljana.
  final square = [
    const LatLng(46.0500, 14.5000),
    const LatLng(46.0500, 14.5026),
    const LatLng(46.0518, 14.5026),
    const LatLng(46.0518, 14.5000),
  ];
  final svc = DroneMissionService.instance;

  test('grid covers polygon with serpentine lines inside bbox', () {
    final wps = svc.planGrid(square, const DroneMissionOptions());
    expect(wps.length, greaterThanOrEqualTo(6));
    expect(wps.length.isEven, isTrue);
    for (final w in wps) {
      expect(w.position.latitude, inInclusiveRange(46.0499, 46.0519));
      expect(w.position.longitude, inInclusiveRange(14.4999, 14.5027));
    }
    // Heading 0 = north-south lines. Serpentine: line 1 ends at the same
    // latitude where line 2 starts, one line spacing (~22 m) further east.
    expect(
      (wps[1].position.latitude - wps[2].position.latitude).abs(),
      lessThan(0.00001),
    );
    expect(wps[2].position.longitude, greaterThan(wps[1].position.longitude));
  });

  test('degenerate polygon yields no waypoints', () {
    expect(svc.planGrid(const [LatLng(46, 14)], const DroneMissionOptions()),
        isEmpty);
  });

  test('kmz contains wpml files', () {
    final wps = svc.planGrid(square, const DroneMissionOptions());
    final bytes = svc.buildKmz(name: 't', waypoints: wps);
    final names = ZipDecoder().decodeBytes(bytes).files.map((f) => f.name);
    expect(names, containsAll(['wpmz/template.kml', 'wpmz/waylines.wpml']));
  });
}

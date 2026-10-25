import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/drone_photo_service.dart';
import 'package:latlong2/latlong.dart';

List<int> fakeJpeg({
  required double lat,
  required double lon,
  double relAlt = 60,
  double yaw = 0,
  double pitch = -90,
  int width = 8192,
  int height = 6144,
}) {
  final xmp = '<x:xmpmeta><rdf:Description '
      'drone-dji:GpsLatitude="$lat" drone-dji:GpsLongitude="$lon" '
      'drone-dji:RelativeAltitude="$relAlt" '
      'drone-dji:GimbalYawDegree="$yaw" '
      'drone-dji:GimbalPitchDegree="$pitch"/></x:xmpmeta>';
  final xmpBytes = xmp.codeUnits;
  final app1Len = xmpBytes.length + 2;
  return [
    0xFF, 0xD8,
    0xFF, 0xE1, app1Len >> 8, app1Len & 0xFF, ...xmpBytes,
    // SOF0: length 17, precision 8, height, width, 3 components.
    0xFF, 0xC0, 0, 17, 8, height >> 8, height & 0xFF, width >> 8, width & 0xFF,
    3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1,
  ];
}

void main() {
  final svc = DronePhotoService.instance;
  final square = [
    const LatLng(46.0500, 14.5000),
    const LatLng(46.0500, 14.5026),
    const LatLng(46.0518, 14.5026),
    const LatLng(46.0518, 14.5000),
  ];

  test('parses DJI XMP position, heading, pitch and JPEG size', () {
    final meta = svc.parseMeta(
      File('a.jpg'),
      fakeJpeg(lat: 46.051, lon: 14.501, yaw: 123.4),
    )!;
    expect(meta.position.latitude, 46.051);
    expect(meta.position.longitude, 14.501);
    expect(meta.relativeAltitudeM, 60);
    expect(meta.headingDeg, 123.4);
    expect(meta.isNadir, isTrue);
    expect((meta.width, meta.height), (8192, 6144));
  });

  test('returns null for a file without DJI position', () {
    expect(svc.parseMeta(File('a.jpg'), [0xFF, 0xD8, 0xFF, 0xD9]), isNull);
  });

  test('readAll keeps photos on the parcel and counts the rest', () async {
    final dir = await Directory.systemTemp.createTemp('photos_test');
    addTearDown(() => dir.delete(recursive: true));
    File write(String name, List<int> bytes) =>
        File('${dir.path}/$name')..writeAsBytesSync(bytes);

    final files = [
      write('in.jpg', fakeJpeg(lat: 46.0509, lon: 14.5013)),
      // About 1 km north, far outside.
      write('out.jpg', fakeJpeg(lat: 46.0600, lon: 14.5013)),
      write('tilted.jpg', fakeJpeg(lat: 46.0509, lon: 14.5013, pitch: -45)),
      write('plain.jpg', [0xFF, 0xD8, 0xFF, 0xD9]),
    ];
    final scan = await svc.readAll(files, square);
    expect(scan.inside.map((p) => p.file.path.split('/').last), ['in.jpg']);
    expect(scan.outside, 1);
    expect(scan.notNadir, 1);
    expect(scan.unreadable, 1);
    expect(scan.total, 4);
  });

  test('a photo just outside whose footprint overlaps the edge is kept',
      () async {
    final dir = await Directory.systemTemp.createTemp('photos_edge');
    addTearDown(() => dir.delete(recursive: true));
    // About 11 m north of the parcel. The kept footprint reaches 20 m.
    final f = File('${dir.path}/edge.jpg')
      ..writeAsBytesSync(fakeJpeg(lat: 46.0519, lon: 14.5013));
    final scan = await svc.readAll([f], square);
    expect(scan.inside, hasLength(1));
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/drone_bundle_service.dart';
import 'package:gozdar/services/drone_mission_service.dart';
import 'package:gozdar/services/parcel_pdf_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final square = [
    const LatLng(46.0500, 14.5000),
    const LatLng(46.0500, 14.5026),
    const LatLng(46.0518, 14.5026),
    const LatLng(46.0518, 14.5000),
  ];

  test('bundle holds plan, boundary, ortho + world file, photos, manifest',
      () async {
    final tmp = await Directory.systemTemp.createTemp('bundle_test');
    addTearDown(() => tmp.delete(recursive: true));
    final photo = File('${tmp.path}/DJI_0001.JPG')
      ..writeAsBytesSync([1, 2, 3, 4]);

    const options = DroneMissionOptions();
    final svc = DroneMissionService.instance;
    final wps = svc.planGrid(square, options);
    final ortho = GeoreferencedImage(
      png: Uint8List.fromList([0, 1, 2]),
      width: 10,
      height: 10,
      zoom: 18,
      originX: 1000,
      originY: 2000,
      pixelSize: 0.5,
    );

    final file = await DroneBundleService.instance.writeBundle(
      outPath: '${tmp.path}/out.zip',
      parcelName: 'Test',
      cadastralId: '1234/5',
      polygon: square,
      options: options,
      waypoints: wps,
      kmz: svc.buildKmz(name: 'Test', waypoints: wps, options: options),
      referenceOrtho: ortho,
      photos: [photo],
    );

    final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
    final names = archive.files.map((f) => f.name).toSet();
    expect(
      names,
      containsAll([
        'mission/mission.kmz',
        'parcel.geojson',
        'reference-ortho.png',
        'reference-ortho.pgw',
        'reference-ortho.prj',
        'images/DJI_0001.JPG',
        'manifest.json',
      ]),
    );

    final manifest = jsonDecode(
      utf8.decode(archive.findFile('manifest.json')!.content as List<int>),
    ) as Map<String, dynamic>;
    expect(manifest['images']['count'], 1);
    expect(manifest['mission']['waypoints'], wps.length);

    // World file: pixel size, no rotation, pixel-centre origin of top-left.
    final wld = utf8
        .decode(archive.findFile('reference-ortho.pgw')!.content as List<int>)
        .split('\n');
    expect(wld, [
      '0.500000',
      '0.000000',
      '0.000000',
      '-0.500000',
      '1000.250000',
      '1999.750000',
    ]);
  });
}

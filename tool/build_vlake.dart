// Reproject the Vlake (forest skid-road) GeoJSON from D48/GK (EPSG:3912) to
// WGS84 and pack it into a compact binary asset (assets/vlake.bin) that the app
// loads far faster and smaller than the ~27 MB source GeoJSON.
//
// Run from the project root:
//   dart run tool/build_vlake.dart [input.geojson] [output.bin]
//
// Binary format (little-endian):
//   uint32  magic   = 0x564C4B31 ("VLK1")
//   uint32  count   = number of polylines
//   repeat count times:
//     uint32 n      = number of points
//     n × (float32 lat, float32 lng)
//
// float32 gives ~0.5 m resolution at Slovenian latitudes — fine for an overlay.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:proj4dart/proj4dart.dart' as proj4;

const _magic = 0x564C4B31;

// EPSG:3912 — D48/GK (Slovenia 1948 / Gauss-Krüger), Bessel ellipsoid, with the
// 7-parameter datum shift to WGS84 (proj4 export from epsg.io/3912).
const _epsg3912 =
    '+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 +x_0=500000 +y_0=-5000000 '
    '+ellps=bessel +towgs84=426.9,142.6,460.1,4.91,4.49,-12.42,17.1 '
    '+units=m +no_defs';

void main(List<String> args) {
  final inPath = args.isNotEmpty
      ? args[0]
      : '/Volumes/Disk/vlake_shape_D48GK.geojson';
  final outPath = args.length > 1 ? args[1] : 'assets/vlake.bin';

  final src = proj4.Projection.add('EPSG:3912', _epsg3912);
  final wgs84 = proj4.Projection.get('EPSG:4326')!;

  stdout.writeln('Reading $inPath ...');
  final json = jsonDecode(File(inPath).readAsStringSync());
  final features = (json['features'] as List).cast<Map<String, dynamic>>();

  final builder = BytesBuilder();
  final header = ByteData(8)
    ..setUint32(0, _magic, Endian.little)
    ..setUint32(4, features.length, Endian.little);
  builder.add(header.buffer.asUint8List());

  var totalPoints = 0;
  for (final f in features) {
    final geom = f['geometry'] as Map<String, dynamic>?;
    final coords = geom?['coordinates'] as List?;
    if (coords == null || coords.isEmpty) {
      builder.add((ByteData(4)..setUint32(0, 0, Endian.little))
          .buffer
          .asUint8List());
      continue;
    }
    final n = coords.length;
    final block = ByteData(4 + n * 8)..setUint32(0, n, Endian.little);
    var off = 4;
    for (final c in coords) {
      final p = src.transform(
        wgs84,
        proj4.Point(x: (c[0] as num).toDouble(), y: (c[1] as num).toDouble()),
      );
      // p.x = lon, p.y = lat
      block.setFloat32(off, p.y, Endian.little); // lat
      block.setFloat32(off + 4, p.x, Endian.little); // lng
      off += 8;
    }
    builder.add(block.buffer.asUint8List());
    totalPoints += n;
  }

  File(outPath).writeAsBytesSync(builder.toBytes());
  final mb = (File(outPath).lengthSync() / (1024 * 1024)).toStringAsFixed(1);
  stdout.writeln(
    'Wrote $outPath  (${features.length} lines, $totalPoints points, $mb MB)',
  );
}

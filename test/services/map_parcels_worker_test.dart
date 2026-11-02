import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/map_parcels_worker.dart';
import 'package:gozdar/services/owner_lookup_service.dart';
import 'package:gozdar/services/parcel_lookup_service.dart';
import 'package:gozdar/services/public_parcel_settings.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqlite3/sqlite3.dart';

/// A `poly` blob (see [ParcelLookupService]) with one ring of [lonLat] pairs.
Uint8List _poly(List<(double, double)> lonLat) {
  final data = ByteData(5 + 4 + lonLat.length * 8)
    ..setUint8(0, ParcelLookupService.blobVersion)
    ..setUint32(1, 1, Endian.little)
    ..setUint32(5, lonLat.length, Endian.little);
  var offset = 9;
  for (final (lon, lat) in lonLat) {
    data.setInt32(offset, (lon * 1e7).round(), Endian.little);
    data.setInt32(offset + 4, (lat * 1e7).round(), Endian.little);
    offset += 8;
  }
  return data.buffer.asUint8List();
}

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('map_parcels_worker');

    final parcels = sqlite3.open('${dir.path}/parcels-test.sqlite');
    parcels.execute(
      'CREATE TABLE parcels (id INTEGER PRIMARY KEY, sifko INTEGER, '
      'parcela TEXT, area REAL, eid TEXT, poly BLOB, min_lon REAL, '
      'max_lon REAL, min_lat REAL, max_lat REAL)',
    );
    void parcel(int sifko, String parcela, String eid, double lon, double lat) {
      parcels.execute(
        'INSERT INTO parcels (sifko, parcela, area, eid, poly, min_lon, '
        'max_lon, min_lat, max_lat) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          sifko, parcela, 100.0, eid,
          _poly([(lon, lat), (lon + .001, lat), (lon + .001, lat + .001)]),
          lon, lon + .001, lat, lat + .001,
        ],
      );
    }

    parcel(1651, '100', 'e1', 14.50, 45.60);
    parcel(1651, '101/2', 'e2', 14.51, 45.61);
    parcel(1651, '900', 'far', 15.50, 46.50); // outside the queried bounds
    parcels.close();

    final public = sqlite3.open('${dir.path}/public.sqlite');
    public.execute('CREATE TABLE names (id INTEGER PRIMARY KEY, naziv TEXT)');
    public.execute(
      'CREATE TABLE owners (sifko INTEGER, parcela TEXT, name_id INTEGER, '
      'vloga TEXT)',
    );
    public.execute("INSERT INTO names VALUES (1, 'OBČINA LOŠKA DOLINA')");
    public.execute("INSERT INTO owners VALUES (1651, '100', 1, 'L')");
    public.close();

    ParcelLookupService.instance.openForTesting('${dir.path}/parcels-test.sqlite');
    OwnerLookupService.instance.openPublicForTesting('${dir.path}/public.sqlite');
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  final bounds = LatLngBounds(const LatLng(45.5, 14.4), const LatLng(45.7, 14.6));

  test('loads the parcels of a viewport off the UI isolate', () async {
    final result = await MapParcelsWorker.instance.parcelsInBounds(
      bounds,
      categories: false,
    );
    expect(
      result.parcels.map((p) => p.parcelNumber),
      unorderedEquals(['100', '101/2']),
    );
    final p = result.parcels.firstWhere((p) => p.id == 'e1');
    expect(p.cadastralMunicipality, 1651);
    expect(p.polygon, hasLength(3));
    expect(p.polygon.first.latitude, closeTo(45.60, 1e-6));
    expect(p.polygon.first.longitude, closeTo(14.50, 1e-6));
    expect(result.categories, isEmpty);
  });

  test('adds public-owner categories when asked', () async {
    final result = await MapParcelsWorker.instance.parcelsInBounds(
      bounds,
      categories: true,
    );
    expect(result.categories, {'e1': PublicOwnerCategory.obcina});
  });
}

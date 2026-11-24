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

/// A `poly` blob of several rings.
Uint8List _polyRings(List<List<(double, double)>> rings) {
  final size = rings.fold(5, (n, r) => n + 4 + r.length * 8);
  final data = ByteData(size)
    ..setUint8(0, ParcelLookupService.blobVersion)
    ..setUint32(1, rings.length, Endian.little);
  var offset = 5;
  for (final ring in rings) {
    data.setUint32(offset, ring.length, Endian.little);
    offset += 4;
    for (final (lon, lat) in ring) {
      data.setInt32(offset, (lon * 1e7).round(), Endian.little);
      data.setInt32(offset + 4, (lat * 1e7).round(), Endian.little);
      offset += 8;
    }
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
          sifko,
          parcela,
          100.0,
          eid,
          _poly([(lon, lat), (lon + .001, lat), (lon + .001, lat + .001)]),
          lon,
          lon + .001,
          lat,
          lat + .001,
        ],
      );
    }

    parcel(1651, '100', 'e1', 14.50, 45.60);
    parcel(1651, '101/2', 'e2', 14.51, 45.61);
    parcel(1651, '900', 'far', 15.50, 46.50); // outside the queried bounds
    // Two pieces, the first with a hole; outside the queried bounds.
    List<(double, double)> box(double lon, double lat, double size) => [
      (lon, lat),
      (lon + size, lat),
      (lon + size, lat + size),
      (lon, lat + size),
      (lon, lat),
    ];
    parcels.execute(
      'INSERT INTO parcels (sifko, parcela, area, eid, poly, min_lon, '
      'max_lon, min_lat, max_lat) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        302759,
        '5000',
        100.0,
        'multi',
        _polyRings([
          box(16.000, 46.000, .010),
          box(16.002, 46.002, .002),
          box(16.020, 46.000, .005),
        ]),
        16.000,
        16.025,
        46.000,
        46.010,
      ],
    );
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

    ParcelLookupService.instance.openForTesting(
      '${dir.path}/parcels-test.sqlite',
    );
    OwnerLookupService.instance.openPublicForTesting(
      '${dir.path}/public.sqlite',
    );
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  final bounds = LatLngBounds(
    const LatLng(45.5, 14.4),
    const LatLng(45.7, 14.6),
  );

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

  test('past the limit, on-screen parcels come first', () async {
    // The screen holds only e2; the padded bounds hold e1 too.
    final screen = LatLngBounds(
      const LatLng(45.609, 14.509),
      const LatLng(45.612, 14.512),
    );
    final cut = await MapParcelsWorker.instance.parcelsInBounds(
      bounds,
      visible: screen,
      categories: false,
      limit: 1,
    );
    expect(cut.parcels.map((p) => p.id), ['e2']);
    expect(cut.truncated, isTrue);

    final all = await MapParcelsWorker.instance.parcelsInBounds(
      bounds,
      visible: screen,
      categories: false,
    );
    expect(all.parcels.map((p) => p.id).first, 'e2');
    expect(all.parcels, hasLength(2));
    expect(all.truncated, isFalse);
  });

  test('every parcel on screen is drawn, however low the limit', () async {
    final all = await MapParcelsWorker.instance.parcelsInBounds(
      bounds,
      categories: false,
      limit: 1,
    );
    expect(all.parcels, hasLength(2));
    expect(all.truncated, isFalse);

    final capped = await MapParcelsWorker.instance.parcelsInBounds(
      bounds,
      categories: false,
      limit: 1,
      screenLimit: 1,
    );
    expect(capped.parcels, hasLength(1));
    expect(capped.truncated, isTrue);
  });

  test('a parcel of several pieces gives every piece, but no hole', () {
    List<(double, double)> box(double lon, double lat, double size) => [
      (lon, lat),
      (lon + size, lat),
      (lon + size, lat + size),
      (lon, lat + size),
      (lon, lat),
    ];
    final rings = MapParcelsWorker.outerRingsForTesting(
      _polyRings([
        box(14.50, 45.60, .010), // first piece
        box(14.502, 45.602, .002), // its hole
        box(14.52, 45.60, .005), // second piece, apart from the first
      ]),
    );
    expect(rings, hasLength(2));
    expect(rings[0][0], 145000000);
    expect(rings[1][0], 145200000);
  });

  test('a tap finds a parcel by any of its pieces, not by its hole', () {
    final svc = ParcelLookupService.instance;
    expect(svc.parcelAt(const LatLng(46.008, 16.008))?.id, 'multi');
    final second = svc.parcelAt(const LatLng(46.002, 16.022));
    expect(second?.id, 'multi');
    // The shape is the piece that was tapped.
    expect(second!.polygon.first.longitude, closeTo(16.020, 1e-6));
    expect(svc.parcelAt(const LatLng(46.003, 16.003)), isNull); // the hole
    expect(svc.parcelAt(const LatLng(46.002, 16.015)), isNull); // between
  });

  test('then the nearest to the screen centre', () async {
    // Both on screen; the centre is next to e1.
    final screen = LatLngBounds(
      const LatLng(45.59, 14.49),
      const LatLng(45.615, 14.515),
    );
    final nearest = await MapParcelsWorker.instance.parcelsInBounds(
      bounds,
      visible: LatLngBounds(
        const LatLng(45.595, 14.495),
        const LatLng(45.607, 14.507),
      ),
      categories: false,
      limit: 1,
    );
    expect(nearest.parcels.map((p) => p.id), ['e1']);
    final both = await MapParcelsWorker.instance.parcelsInBounds(
      bounds,
      visible: screen,
      categories: false,
      limit: 2,
    );
    expect(both.parcels, hasLength(2));
    expect(both.truncated, isFalse);
  });
}

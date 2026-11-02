import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/models/received_share.dart';
import 'package:gozdar/services/database_service.dart';
import 'package:latlong2/latlong.dart';

/// Square parcel with its south-west corner at ([lat], [lng]) and [size]
/// degrees per side.
Parcel square(String name, double lat, double lng, double size) => Parcel(
      name: name,
      polygon: [
        LatLng(lat, lng),
        LatLng(lat + size, lng),
        LatLng(lat + size, lng + size),
        LatLng(lat, lng + size),
      ],
    );

MapLocation mark(double lat, double lng, {LocationType type = LocationType.secnja}) =>
    MapLocation(name: 'Drevo', latitude: lat, longitude: lng, type: type);

ReceivedShare received(String id, {String json = '{}', int days = 10}) => ReceivedShare(
      shareId: id,
      payloadJson: json,
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: days)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final service = DatabaseService();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service.setDatabaseForTesting(db);
  });

  tearDown(() => service.resetForTesting());

  Future<MapLocation> stored(int id) async =>
      (await service.getAllLocations()).firstWhere((l) => l.id == id);

  test('insertLocation assigns the containing parcel to a sečnja mark', () async {
    final parcelId = await service.insertParcel(square('A', 46, 14, 0.01));
    final id = await service.insertLocation(mark(46.005, 14.005));
    expect((await stored(id)).parcelId, parcelId);
  });

  test('overlapping parcels: smallest wins', () async {
    await service.insertParcel(square('Big', 46, 14, 0.1));
    final smallId = await service.insertParcel(square('Small', 46, 14, 0.01));
    final id = await service.insertLocation(mark(46.005, 14.005));
    expect((await stored(id)).parcelId, smallId);
  });

  test('plain points do not get a parcelId', () async {
    await service.insertParcel(square('A', 46, 14, 0.01));
    final id = await service.insertLocation(
      mark(46.005, 14.005, type: LocationType.point),
    );
    expect((await stored(id)).parcelId, isNull);
  });

  test('getSecnjaCountsByParcel counts per parcel', () async {
    final a = await service.insertParcel(square('A', 46, 14, 0.01));
    final b = await service.insertParcel(square('B', 47, 14, 0.01));
    await service.insertLocation(mark(46.005, 14.005));
    await service.insertLocation(mark(46.006, 14.006));
    await service.insertLocation(mark(47.005, 14.005));
    await service.insertLocation(mark(10, 10));
    expect(await service.getSecnjaCountsByParcel(), {a: 2, b: 1});
    expect(await service.countSecnjaWithoutParcel(), 1);
    expect(await service.getSecnjaByParcel(a), hasLength(2));
  });

  test('backfillSecnjaParcels links existing marks', () async {
    final a = await service.insertParcel(square('A', 46, 14, 0.01));
    final rowId = await db.into(db.mapLocations).insert(
          MapLocationsCompanion.insert(
            name: 'Old',
            latitude: 46.005,
            longitude: 14.005,
            typeIndex: Value(LocationType.secnja.index),
            createdAt: DateTime(2025),
          ),
        );
    expect((await stored(rowId)).parcelId, isNull);
    await db.backfillSecnjaParcels();
    expect((await stored(rowId)).parcelId, a);
  });

  test('deleteParcelWithContents removes marks linked by parcelId even outside the polygon',
      () async {
    final a = await service.insertParcel(square('A', 46, 14, 0.01));
    final outside = mark(50, 10)..parcelId = a;
    await service.insertLocation(outside);
    await service.deleteParcelWithContents(a);
    expect(await service.getAllLocations(), isEmpty);
  });

  test('saveParcelShare / clearParcelShare round trip', () async {
    final a = await service.insertParcel(square('A', 46, 14, 0.01));
    final expires = DateTime(2026, 12, 2);
    await service.saveParcelShare(
      a,
      shareId: 'abc123',
      editToken: 'tok',
      hash: 'h1',
      sharedAt: DateTime(2026, 11, 2),
      expiresAt: expires,
    );
    var p = (await service.getParcel(a))!;
    expect(p.isShared, isTrue);
    expect(p.shareId, 'abc123');
    expect(p.shareEditToken, 'tok');
    expect(p.shareHash, 'h1');
    expect(p.shareExpiresAt, expires);

    // Editing the parcel keeps the share.
    await service.updateParcel(p.copyWith(name: 'Renamed'));
    p = (await service.getParcel(a))!;
    expect(p.shareId, 'abc123');

    await service.clearParcelShare(a);
    p = (await service.getParcel(a))!;
    expect(p.isShared, isFalse);
    expect(p.shareEditToken, isNull);
  });

  test('upsertReceivedShare twice keeps one row, latest payload, visibility kept', () async {
    await service.upsertReceivedShare(received('abc', json: '{"a":1}'));
    await service.setReceivedShareVisible('abc', false);
    await service.upsertReceivedShare(received('abc', json: '{"a":2}'));
    final all = await service.getReceivedShares();
    expect(all, hasLength(1));
    expect(all.single.payloadJson, '{"a":2}');
    expect(all.single.visible, isFalse);
  });

  test('getReceivedShares hides expired shares without network', () async {
    await service.upsertReceivedShare(received('old', days: -1));
    await service.upsertReceivedShare(received('new'));
    expect((await service.getReceivedShares()).map((s) => s.shareId), ['new']);
  });

  test('purgeExpiredReceivedShares deletes them', () async {
    await service.upsertReceivedShare(received('old', days: -1));
    await service.upsertReceivedShare(received('new'));
    expect(await service.purgeExpiredReceivedShares(), 1);
    await service.deleteReceivedShare('new');
    expect(await db.select(db.receivedShares).get(), isEmpty);
  });
}

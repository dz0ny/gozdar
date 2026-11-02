import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/services/cadastral_service.dart';
import 'package:gozdar/services/database_service.dart';
import 'package:gozdar/services/secnja_marking.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:flutter/widgets.dart' show Locale;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('marking', markingTests);
  group('auto import', autoImportTests);

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

  test('saving a parcel links marks made before it existed', () async {
    final id = await service.insertLocation(mark(46.005, 14.005));
    expect((await stored(id)).parcelId, isNull);
    final a = await service.insertParcel(square('A', 46, 14, 0.01));
    expect((await stored(id)).parcelId, a);
  });

  test('editing a polygon links marks that now fall inside', () async {
    final a = await service.insertParcel(square('A', 46, 14, 0.01));
    final id = await service.insertLocation(mark(46.015, 14.005));
    expect((await stored(id)).parcelId, isNull);
    final p = (await service.getParcel(a))!;
    await service.updateParcel(p.copyWith(polygon: square('A', 46, 14, 0.02).polygon));
    expect((await stored(id)).parcelId, a);
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

}

void markingTests() {
  final l10n = lookupAppLocalizations(const Locale('sl'));
  late AppDatabase db;
  final service = DatabaseService();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service.setDatabaseForTesting(db);
  });

  tearDown(() => service.resetForTesting());

  test('markSecnjaAt uses the parcel under the point at mark time', () async {
    final a = await service.insertParcel(square('A', 46, 14, 0.01));
    final b = await service.insertParcel(square('B', 47, 14, 0.01));

    final first = await markSecnjaAt(const LatLng(46.005, 14.005), species: 'Smreka', l10n: l10n);
    final second = await markSecnjaAt(const LatLng(47.005, 14.005), l10n: l10n);
    final third = await markSecnjaAt(const LatLng(46.006, 14.006), species: 'Smreka', l10n: l10n);

    expect([first.parcelId, second.parcelId, third.parcelId], [a, b, a]);
    expect([first.name, second.name, third.name], ['Smreka 1', 'Drevo 1', 'Smreka 2']);
    expect(first.id, isNot(0));
  });
}

void autoImportTests() {
  late AppDatabase db;
  final service = DatabaseService();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service.setDatabaseForTesting(db);
  });

  tearDown(() => service.resetForTesting());

  const cadastral = CadastralParcel(
    id: 'p1',
    cadastralMunicipality: 1717,
    parcelNumber: '1043/2',
    area: 1000,
    polygon: [LatLng(46, 14), LatLng(46.01, 14), LatLng(46.01, 14.01), LatLng(46, 14.01)],
  );

  Future<bool> fakeImport(CadastralParcel c) async {
    await service.insertParcel(Parcel(
      name: '1717 - ${c.parcelNumber}',
      polygon: c.polygon,
      cadastralMunicipality: c.cadastralMunicipality,
      parcelNumber: c.parcelNumber,
    ));
    return true;
  }

  test('a mark outside saved parcels imports the cadastral parcel and links to it', () async {
    final id = await service.insertLocation(mark(46.005, 14.005));
    final queried = <LatLng>[];
    final parcelId = await importSecnjaParcelAt(
      const LatLng(46.005, 14.005),
      query: (p) async {
        queried.add(p);
        return cadastral;
      },
      import: fakeImport,
    );
    expect(queried, hasLength(1));
    expect(parcelId, isNotNull);
    expect((await stored(service, id)).parcelId, parcelId);
  });

  test('a mark inside a saved parcel imports nothing', () async {
    final a = await service.insertParcel(square('A', 46, 14, 0.01));
    var queried = false;
    final parcelId = await importSecnjaParcelAt(
      const LatLng(46.005, 14.005),
      query: (_) async {
        queried = true;
        return cadastral;
      },
      import: fakeImport,
    );
    expect(queried, isFalse);
    expect(parcelId, a);
  });

  test('no cadastral parcel found leaves the mark outside', () async {
    final parcelId = await importSecnjaParcelAt(
      const LatLng(46.005, 14.005),
      query: (_) async => null,
      import: fakeImport,
    );
    expect(parcelId, isNull);
  });
}

Future<MapLocation> stored(DatabaseService service, int id) async =>
    (await service.getAllLocations()).firstWhere((l) => l.id == id);

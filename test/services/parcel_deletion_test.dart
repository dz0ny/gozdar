import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/services/database_service.dart';
import 'package:latlong2/latlong.dart';

Parcel square(String name, double lat, double lng, double size) => Parcel(
  name: name,
  polygon: [
    LatLng(lat, lng),
    LatLng(lat + size, lng),
    LatLng(lat + size, lng + size),
    LatLng(lat, lng + size),
  ],
);

MapLocation point(double lat, double lng) =>
    MapLocation(name: 'Točka', latitude: lat, longitude: lng);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final service = DatabaseService();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service.setDatabaseForTesting(db);
  });

  tearDown(() => service.resetForTesting());

  test('deleteParcelWithContents removes the parcel, its logs and the '
      'locations on it, and nothing else', () async {
    final parcelId = await service.insertParcel(square('A', 46, 14, 0.01));
    final otherId = await service.insertParcel(square('B', 47, 15, 0.01));
    await service.insertLog(LogEntry(volume: 1, parcelId: parcelId));
    await service.insertLog(LogEntry(volume: 2, parcelId: parcelId));
    final keptLog = await service.insertLog(
      LogEntry(volume: 3, parcelId: otherId),
    );
    await service.insertLocation(point(46.005, 14.005)); // inside A
    await service.insertLocation(point(46.002, 14.008)); // inside A
    final outside = await service.insertLocation(point(46.5, 14.5));

    final deleted = await service.deleteParcelWithContents(parcelId);

    expect(deleted, {'logs': 2, 'locations': 2});
    expect((await service.getAllParcels()).map((p) => p.id), [otherId]);
    expect((await service.getAllLogs()).map((l) => l.id), [keptLog]);
    expect((await service.getAllLocations()).map((l) => l.id), [outside]);
  });

  test(
    'deleteParcelWithContents on a missing parcel changes nothing',
    () async {
      await service.insertLocation(point(46.005, 14.005));

      expect(await service.deleteParcelWithContents(999), {
        'logs': 0,
        'locations': 0,
      });
      expect(await service.getAllLocations(), hasLength(1));
    },
  );
}

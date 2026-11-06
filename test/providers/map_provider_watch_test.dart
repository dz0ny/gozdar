import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/providers/map_provider.dart';
import 'package:gozdar/services/database_service.dart';

/// Other screens write straight to the database and no longer tell the map
/// to reload; the map has to follow the database by itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MapProvider provider;
  final service = DatabaseService();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service.setDatabaseForTesting(db);
    provider = MapProvider(databaseService: service);
    await provider.loadParcels();
    await provider.loadLocations();
    await provider.loadGeolocatedLogs();
  });

  tearDown(() async {
    provider.dispose();
    await service.resetForTesting();
  });

  /// Waits until [check] holds, for drift to re-run the watched query.
  Future<void> until(bool Function() check) async {
    for (var i = 0; i < 50 && !check(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(check(), isTrue);
  }

  const square = [
    LatLng(46.0, 14.0),
    LatLng(46.0, 14.001),
    LatLng(46.001, 14.001),
    LatLng(46.001, 14.0),
  ];

  test('a parcel saved elsewhere shows on the map', () async {
    expect(provider.parcels, isEmpty);
    await service.insertParcel(Parcel(name: 'Gozd', polygon: square));
    await until(() => provider.parcels.length == 1);
  });

  test('deleting a parcel with contents clears it from the map', () async {
    final id = await service.insertParcel(
      Parcel(name: 'Gozd', polygon: square),
    );
    await service.insertLocation(
      MapLocation(name: 'Smreka', latitude: 46.0005, longitude: 14.0005),
    );
    await service.insertLog(
      LogEntry(volume: 1, latitude: 46.0005, longitude: 14.0005),
    );
    await until(
      () =>
          provider.parcels.length == 1 &&
          provider.locations.length == 1 &&
          provider.geolocatedLogs.length == 1,
    );

    await service.deleteParcelWithContents(id);

    await until(
      () =>
          provider.parcels.isEmpty &&
          provider.locations.isEmpty &&
          provider.geolocatedLogs.isEmpty,
    );
  });

  test('only logs with a position reach the map', () async {
    await service.insertLog(LogEntry(volume: 1));
    await service.insertLog(
      LogEntry(volume: 2, latitude: 46.1, longitude: 14.1),
    );
    await until(() => provider.geolocatedLogs.length == 1);
    expect(provider.geolocatedLogs.single.volume, 2);
  });
}

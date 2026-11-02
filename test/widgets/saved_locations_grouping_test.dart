import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/widgets/saved_locations_sheet.dart';
import 'package:latlong2/latlong.dart';

Parcel square(int id, String name, double lat) => Parcel(
  id: id,
  name: name,
  polygon: [
    LatLng(lat, 14),
    LatLng(lat + 0.01, 14),
    LatLng(lat + 0.01, 14.01),
    LatLng(lat, 14.01),
  ],
);

void main() {
  testWidgets('locations are grouped by parcel, outside ones last', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 6000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: SavedLocationsSheet(
            parcels: [square(1, 'Bukovje', 46), square(2, 'Akacije', 47)],
            locations: [
              MapLocation(
                id: 1,
                name: 'Izvir',
                latitude: 46.005,
                longitude: 14.005,
              ),
              MapLocation(
                id: 2,
                name: 'Smreka 1',
                latitude: 46.006,
                longitude: 14.006,
                type: LocationType.secnja,
                parcelId: 1,
              ),
              MapLocation(
                id: 3,
                name: 'Mejnik',
                latitude: 47.005,
                longitude: 14.005,
              ),
              MapLocation(id: 4, name: 'Daleč', latitude: 10, longitude: 10),
            ],
            logs: [
              LogEntry(
                volume: 1,
                latitude: 47.006,
                longitude: 14.006,
                parcelId: 2,
              ),
            ],
            onNavigate: (_) {},
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    double y(String text) => tester.getTopLeft(find.text(text)).dy;

    // Parcel headers sorted by name, "Izven parcele" last.
    expect(find.text('Akacije'), findsOneWidget);
    expect(find.text('Bukovje'), findsOneWidget);
    expect(find.text('Izven parcele'), findsOneWidget);
    expect(y('Akacije'), lessThan(y('Bukovje')));
    expect(y('Bukovje'), lessThan(y('Izven parcele')));

    // Each item sits under its own parcel.
    expect(y('Mejnik'), inExclusiveRange(y('Akacije'), y('Bukovje')));
    expect(y('Izvir'), inExclusiveRange(y('Bukovje'), y('Izven parcele')));
    expect(y('Smreka 1'), inExclusiveRange(y('Bukovje'), y('Izven parcele')));
    expect(y('Daleč'), greaterThan(y('Izven parcele')));
  });

  testWidgets(
    'a cadastral parcel header shows the number, k.o. and owner; tap opens it',
    (tester) async {
      tester.view.physicalSize = const Size(2400, 6000);
      addTearDown(tester.view.reset);
      final opened = <String>[];
      final parcel = Parcel(
        id: 7,
        name: '304549 - 10000',
        cadastralMunicipality: 304549,
        parcelNumber: '10000',
        owner: 'ŠKOPAC ANA',
        polygon: square(7, 'x', 46).polygon,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('sl'),
          home: Scaffold(
            body: SavedLocationsSheet(
              parcels: [parcel],
              locations: [
                MapLocation(
                  id: 1,
                  name: 'Smreka 1',
                  latitude: 46.005,
                  longitude: 14.005,
                  type: LocationType.secnja,
                  parcelId: 7,
                ),
              ],
              onNavigate: (_) {},
              onEdit: (_) {},
              onDelete: (_) {},
              onOpenParcel: (p) => opened.add(p.name),
            ),
          ),
        ),
      );
      expect(find.text('304549 - 10000'), findsNothing);
      expect(find.text('10000'), findsOneWidget);
      expect(find.text('KO 304549 · ŠKOPAC ANA'), findsOneWidget);
      await tester.tap(find.text('10000'));
      expect(opened, ['304549 - 10000']);
    },
  );
}

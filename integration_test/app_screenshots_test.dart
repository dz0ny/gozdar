import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/main.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/services/database_service.dart';
import 'package:gozdar/services/onboarding_service.dart';
import 'package:gozdar/services/tile_cache_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const screenshotPrefix = String.fromEnvironment('SCREENSHOT_PREFIX');

  testWidgets('captures App Store screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_version': OnboardingService.currentVersion,
    });

    await DatabaseService().initialize();
    await TileCacheService.initialize();
    await OnboardingService.initialize();
    await _seedSampleData();

    await tester.pumpWidget(const GozdarApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();

    await _takeScreenshot(binding, tester, '${screenshotPrefix}01-forest');

    await _tapTab(tester, 'Hlodi');
    await _takeScreenshot(binding, tester, '${screenshotPrefix}02-logs');

    await _tapTab(tester, 'Karta');
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _takeScreenshot(binding, tester, '${screenshotPrefix}03-map');

    await _tapTab(tester, 'Gozd');
    await tester.tap(find.text('Kočevski revir').first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await _takeScreenshot(binding, tester, '${screenshotPrefix}04-parcel');
  });
}

Future<void> _seedSampleData() async {
  final db = DatabaseService();
  final existing = await db.getAllParcels();
  if (existing.any((parcel) => parcel.name == 'Kočevski revir')) {
    return;
  }

  final parcelId = await db.insertParcel(
    Parcel(
      name: 'Kočevski revir',
      owner: 'Janez Troha',
      cadastralMunicipality: 1577,
      parcelNumber: '1284/6',
      notes: 'Mešani sestoj z označeno sečnjo in dovozno potjo.',
      forestType: ForestType.mixed,
      woodAllowance: 42.0,
      woodCut: 13.5,
      treesCut: 18,
      polygon: const [
        LatLng(45.6424, 14.8582),
        LatLng(45.6438, 14.8614),
        LatLng(45.6412, 14.8631),
        LatLng(45.6401, 14.8592),
      ],
      pointNames: const ['Mejnik A', 'Vrhnji rob', 'Vleka', 'Cesta'],
    ),
  );

  await db.insertLocation(
    MapLocation(
      name: 'Skladišče hlodovine',
      latitude: 45.6413,
      longitude: 14.8606,
    ),
  );
  await db.insertLocation(
    MapLocation(
      name: 'Aktivna sečnja',
      latitude: 45.6422,
      longitude: 14.8615,
      type: LocationType.secnja,
    ),
  );

  final logs = [
    (diameter: 42.0, length: 4.0, species: 'Smreka'),
    (diameter: 36.0, length: 5.0, species: 'Bukev'),
    (diameter: 31.0, length: 4.5, species: 'Jelka'),
    (diameter: 48.0, length: 3.5, species: 'Smreka'),
  ];
  for (final log in logs) {
    await db.insertLog(
      LogEntry(
        diameter: log.diameter,
        length: log.length,
        volume: LogEntry.calculateVolume(log.diameter, log.length),
        latitude: 45.6418,
        longitude: 14.8610,
        species: log.species,
        parcelId: parcelId,
        notes: 'Vzorec za App Store posnetke',
      ),
    );
  }
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> _takeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  final bytes = await binding.takeScreenshot(name);
  expect(bytes.isNotEmpty, isTrue);
}

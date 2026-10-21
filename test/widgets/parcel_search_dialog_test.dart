import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/ko_locator.dart';
import 'package:gozdar/services/owner_lookup_service.dart';
import 'package:gozdar/theme/app_theme.dart';
import 'package:gozdar/widgets/parcel_search_dialog.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  KoLocator.instance.loadForTesting(
    File('test/fixtures/ko_index_small.json').readAsStringSync(),
  );

  // Inside BABNO POLJE of the fixture index.
  const babnoCenter = LatLng(45.655, 14.555);

  Future<void> open(WidgetTester tester, {LatLng? center = babnoCenter}) async {
    ParcelSearchDialog.forgetLastSearch();
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.greenTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => ParcelSearchDialog.show(
              context: context,
              mapController: MapController(),
              center: center,
              onParcelFound: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  testWidgets('opens with the KO under the map centre preselected',
      (tester) async {
    await open(tester);

    expect(find.text('Iskanje parcele'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'KO BABNO POLJE (1651)'),
        findsOneWidget);
    // Empty state before anything is typed.
    expect(find.textContaining('Vnesite številko parcele'), findsOneWidget);
    // The field takes focus straight away.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
  });

  testWidgets('no chip value when the map is outside any KO', (tester) async {
    await open(tester, center: const LatLng(48.0, 16.0));
    expect(find.byType(InputChip), findsNothing);
    expect(find.text('Vse katastrske občine'), findsOneWidget);
  });

  testWidgets('a parcel number is suggested in the preselected KO',
      (tester) async {
    await open(tester);
    await type(tester, '123/4');

    expect(find.text('Parcela 123/4'), findsOneWidget);
    expect(find.text('KO BABNO POLJE (1651)'), findsNWidgets(2)); // chip + row
  });

  testWidgets('KO names autocomplete ignoring case and diacritics, and the '
      'tapped KO replaces the chip', (tester) async {
    await open(tester);
    await type(tester, 'sentjur');

    expect(find.text('ŠENTJUR'), findsOneWidget);
    expect(find.text('Katastrska občina 2001'), findsOneWidget);

    await tester.tap(find.text('ŠENTJUR'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'KO ŠENTJUR (2001)'), findsOneWidget);
    expect(find.text('KO BABNO POLJE (1651)'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });

  testWidgets('removing the chip searches every KO; "<KO> <number>" works',
      (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Odstrani katastrsko občino'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);

    await type(tester, 'trg 88');
    expect(find.text('Parcela 88'), findsOneWidget);
    expect(find.text('KO STARI TRG (2002)'), findsOneWidget);
  });

  testWidgets('a number without any KO asks for one', (tester) async {
    await open(tester, center: null);
    await type(tester, '55/1');
    expect(find.textContaining('izberite katastrsko občino'), findsWidgets);
  });

  testWidgets('reopening restores the last query and its suggestions',
      (tester) async {
    await open(tester);
    await type(tester, '123/4');
    expect(find.text('Parcela 123/4'), findsOneWidget);

    await tester.tap(find.byTooltip('Prekliči'));
    await tester.pumpAndSettle();
    expect(find.text('Parcela 123/4'), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '123/4');
    expect(find.text('Parcela 123/4'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'KO BABNO POLJE (1651)'),
        findsOneWidget);
  });

  testWidgets('no matches shows the empty state', (tester) async {
    await open(tester, center: null);
    await type(tester, 'zzzzzz');
    expect(find.text('Ni zadetkov.'), findsOneWidget);
  });

  testWidgets('owner names are suggested with their KO on a second line',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('owners-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/owners.sqlite';
    sqlite3.open(path)
      ..execute('CREATE TABLE owners(sifko INT, parcela TEXT, lastnik TEXT, '
          'naslov TEXT, imeko TEXT, obcina TEXT)')
      ..execute("INSERT INTO owners VALUES "
          "(1651,'1234/2','NOVAK JANEZ','BABNO POLJE 12','BABNO POLJE',NULL),"
          "(1700,'5','NOVAK ANA',NULL,'KOZARIŠČE',NULL)")
      ..close();
    OwnerLookupService.instance.openForTesting(path);

    await open(tester);
    await tester.enterText(find.byType(TextField), 'novak');
    await tester.pump(const Duration(milliseconds: 400));
    // The search runs on a real background isolate.
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pumpAndSettle();

    // Only the owner in the preselected KO.
    expect(find.text('Parcela 1234/2'), findsOneWidget);
    expect(find.text('KO BABNO POLJE • NOVAK JANEZ • BABNO POLJE 12'), findsOneWidget);
    expect(find.text('Parcela 5'), findsNothing);

    // Dropping the KO filter shows both.
    await tester.tap(find.byTooltip('Odstrani katastrsko občino'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pumpAndSettle();
    expect(find.text('Parcela 5'), findsOneWidget);
    expect(find.text('KO KOZARIŠČE • NOVAK ANA'), findsOneWidget);
  });
}

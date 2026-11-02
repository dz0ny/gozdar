import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/widgets/map_long_press_menu.dart';

void main() {
  testWidgets('Navigiraj is a top-level action that closes the sheet first', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: MapLongPressMenu(
            onAddLocation: () {},
            onAddLog: () {},
            onAddSecnja: () {},
            onImportParcel: () {},
            onNavigate: () => calls.add('navigate'),
            onMeasureDistance: () {},
            onMeasureArea: () {},
            mejnikiAvailable: false,
            showMejniki: false,
            onToggleMejniki: (_) {},
            onClose: () => calls.add('close'),
          ),
        ),
      ),
    );
    expect(find.text('Navigiraj'), findsOneWidget);
    await tester.tap(find.text('Navigiraj'));
    await tester.pump();
    expect(calls, ['close', 'navigate']);
  });

  Future<List<String>> pumpParcelMenu(
    WidgetTester tester, {
    required int count,
  }) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MapLongPressMenu(
              onAddLocation: () {},
              onAddLog: () {},
              onAddSecnja: () {},
              onImportParcel: () {},
              onViewParcel: () => calls.add('view'),
              parcelTitle: 'Parc. 1234/5',
              parcelSecnjaCount: count,
              onNavigate: () {},
              onMeasureDistance: () {},
              onMeasureArea: () {},
              mejnikiAvailable: false,
              showMejniki: false,
              onToggleMejniki: (_) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    return calls;
  }

  testWidgets('parcel with marks shows the count and opens the parcel', (
    tester,
  ) async {
    final calls = await pumpParcelMenu(tester, count: 4);
    expect(find.text('🪓 4 za posek'), findsOneWidget);
    await tester.tap(find.text('🪓 4 za posek'));
    expect(calls, ['view']);
  });

  testWidgets('parcel without marks shows no count', (tester) async {
    await pumpParcelMenu(tester, count: 0);
    expect(find.textContaining('za posek'), findsNothing);
  });
}

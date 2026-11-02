import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/widgets/saved_locations_sheet.dart';

void main() {
  Future<List<String>> pump(
    WidgetTester tester, {
    bool deleteSucceeds = true,
  }) async {
    final deleted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: SavedLocationsSheet(
            locations: [
              MapLocation(id: 1, name: 'Izvir', latitude: 46, longitude: 14),
              MapLocation(id: 2, name: 'Mejnik', latitude: 46.1, longitude: 14),
            ],
            onNavigate: (_) {},
            onEdit: (_) {},
            onDelete: (_) {},
            onSwipeDelete: (location) async {
              deleted.add(location.name);
              return deleteSucceeds;
            },
          ),
        ),
      ),
    );
    return deleted;
  }

  Future<void> swipeLeft(WidgetTester tester, String name) async {
    await tester.drag(find.text(name), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('swipe left and confirm deletes the location', (tester) async {
    final deleted = await pump(tester);
    await swipeLeft(tester, 'Izvir');
    await tester.tap(find.text('Izbriši'));
    await tester.pumpAndSettle();
    expect(deleted, ['Izvir']);
    expect(find.text('Izvir'), findsNothing);
    expect(find.text('Mejnik'), findsOneWidget);
  });

  testWidgets('swipe left and cancel keeps the location', (tester) async {
    final deleted = await pump(tester);
    await swipeLeft(tester, 'Izvir');
    await tester.tap(find.text('Prekliči'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.text('Izvir'), findsOneWidget);
  });

  testWidgets('a failed delete keeps the location', (tester) async {
    final deleted = await pump(tester, deleteSucceeds: false);
    await swipeLeft(tester, 'Izvir');
    await tester.tap(find.text('Izbriši'));
    await tester.pumpAndSettle();
    expect(deleted, ['Izvir']);
    expect(find.text('Izvir'), findsOneWidget);
  });
}

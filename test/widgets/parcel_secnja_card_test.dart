import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/services/secnja_share_flow.dart';
import 'package:gozdar/widgets/parcel_data_cards.dart';
import 'package:intl/date_symbol_data_local.dart';

List<MapLocation> marks(int n) => [
      for (var i = 0; i < n; i++)
        MapLocation(name: 'Drevo ${i + 1}', latitude: 46, longitude: 14, type: LocationType.secnja),
    ];

void main() {
  setUpAll(() => initializeDateFormatting());
  group('swipe', swipeTests);

  group('secnjaShareState', () {
    test('not shared', () {
      expect(secnjaShareState(Parcel(name: 'A'), 'h'), SecnjaShareState.notShared);
    });
    test('same hash is unchanged', () {
      final p = Parcel(name: 'A', shareId: 'abc', shareHash: 'h');
      expect(secnjaShareState(p, 'h'), SecnjaShareState.sharedUnchanged);
    });
    test('expired link counts as not shared', () {
      final p = Parcel(
        name: 'A',
        shareId: 'abc',
        shareHash: 'h',
        shareExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(secnjaShareState(p, 'h'), SecnjaShareState.notShared);
    });
    test('different hash is changed', () {
      final p = Parcel(name: 'A', shareId: 'abc', shareHash: 'h');
      expect(secnjaShareState(p, 'other'), SecnjaShareState.sharedChanged);
    });
  });

  Future<List<String>> pumpCard(
    WidgetTester tester, {
    required int count,
    required SecnjaShareState state,
  }) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ParcelSecnjaCard(
              secnja: marks(count),
              onNavigateToPoint: (_, _) {},
              shareState: state,
              expiresAt: DateTime(2026, 12, 2),
              onShare: () => calls.add('share'),
              onRevoke: () => calls.add('revoke'),
            ),
          ),
        ),
      ),
    );
    return calls;
  }

  testWidgets('not shared shows Deli sekaču', (tester) async {
    final calls = await pumpCard(tester, count: 2, state: SecnjaShareState.notShared);
    expect(find.textContaining('velja do'), findsNothing);
    expect(find.text('Prekliči'), findsNothing);
    await tester.tap(find.text('Deli sekaču'));
    expect(calls, ['share']);
  });

  testWidgets('shared unchanged shows Deli znova and the expiry line', (tester) async {
    await pumpCard(tester, count: 2, state: SecnjaShareState.sharedUnchanged);
    expect(find.text('Deli znova'), findsOneWidget);
    expect(find.text('Deljeno · velja do 2. 12. 2026'), findsOneWidget);
  });

  testWidgets('changed shows Posodobi povezavo', (tester) async {
    await pumpCard(tester, count: 2, state: SecnjaShareState.sharedChanged);
    expect(find.text('Posodobi povezavo'), findsOneWidget);
  });

  testWidgets('shared with zero marks still renders with Prekliči and no share button',
      (tester) async {
    final calls = await pumpCard(tester, count: 0, state: SecnjaShareState.sharedChanged);
    expect(find.text('Posodobi povezavo'), findsNothing);
    expect(find.text('Deli sekaču'), findsNothing);
    await tester.tap(find.text('Prekliči'));
    expect(calls, ['revoke']);
  });

  testWidgets('not shared with zero marks renders nothing', (tester) async {
    await pumpCard(tester, count: 0, state: SecnjaShareState.notShared);
    expect(find.byType(Card), findsNothing);
  });
}

void swipeTests() {
  Future<List<String>> pump(WidgetTester tester, {bool deleteSucceeds = true}) async {
    final deleted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ParcelSecnjaCard(
              secnja: [
                MapLocation(id: 1, name: 'Smreka 1', latitude: 46, longitude: 14, type: LocationType.secnja),
                MapLocation(id: 2, name: 'Smreka 2', latitude: 46, longitude: 14, type: LocationType.secnja),
              ],
              onNavigateToPoint: (_, _) {},
              onShare: () {},
              onRevoke: () {},
              onDelete: (mark) async {
                deleted.add(mark.name);
                return deleteSucceeds;
              },
            ),
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

  testWidgets('swipe left and confirm removes the tree', (tester) async {
    final deleted = await pump(tester);
    await swipeLeft(tester, 'Smreka 1');
    await tester.tap(find.text('Izbriši'));
    await tester.pumpAndSettle();
    expect(deleted, ['Smreka 1']);
    expect(find.text('Smreka 1'), findsNothing);
    expect(find.text('Smreka 2'), findsOneWidget);
  });

  testWidgets('swipe left and cancel keeps the tree', (tester) async {
    final deleted = await pump(tester);
    await swipeLeft(tester, 'Smreka 1');
    await tester.tap(find.text('Prekliči'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.text('Smreka 1'), findsOneWidget);
  });

  testWidgets('a failed delete keeps the tree', (tester) async {
    final deleted = await pump(tester, deleteSucceeds: false);
    await swipeLeft(tester, 'Smreka 1');
    await tester.tap(find.text('Izbriši'));
    await tester.pumpAndSettle();
    expect(deleted, ['Smreka 1']);
    expect(find.text('Smreka 1'), findsOneWidget);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/received_share.dart';
import 'package:gozdar/models/secnja_share.dart';
import 'package:gozdar/widgets/map_layer_selector.dart';

ReceivedShare share(String id, {String? owner}) => ReceivedShare(
      shareId: id,
      payloadJson: jsonEncode(SecnjaSharePayload(
        parcelNumber: '1234/5',
        koName: 'Dolenja vas',
        owner: owner,
        points: [SecnjaPoint(name: 'Drevo 1', lat: 46, lng: 14)],
        createdAt: DateTime.utc(2026, 11, 2),
      ).toJson()),
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 28, hours: 1)),
    );

void main() {
  Future<List<String>> pump(WidgetTester tester, List<ReceivedShare> shares) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: ReceivedSharesSection(
            shares: shares,
            onToggle: (id, v) => calls.add('toggle:$id:$v'),
            onDelete: (id) => calls.add('delete:$id'),
          ),
        ),
      ),
    );
    return calls;
  }

  testWidgets('renders one row per share with days left', (tester) async {
    await pump(tester, [share('a', owner: 'Janez N.'), share('b')]);
    expect(find.text('PREJETO'), findsOneWidget);
    expect(find.text('🪓 Sečnja 1234/5 · Janez N. · še 29 dni'), findsOneWidget);
    expect(find.text('🪓 Sečnja 1234/5 · Dolenja vas · še 29 dni'), findsOneWidget);
  });

  testWidgets('switch calls onToggle', (tester) async {
    final calls = await pump(tester, [share('a')]);
    await tester.tap(find.byType(Switch));
    expect(calls, ['toggle:a:false']);
  });

  testWidgets('delete asks to confirm then calls onDelete', (tester) async {
    final calls = await pump(tester, [share('a')]);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Odstranim prejeto sečnjo?'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.tap(find.text('Izbriši'));
    await tester.pumpAndSettle();
    expect(calls, ['delete:a']);
  });

  testWidgets('section absent when list empty', (tester) async {
    await pump(tester, const []);
    expect(find.text('PREJETO'), findsNothing);
  });
}

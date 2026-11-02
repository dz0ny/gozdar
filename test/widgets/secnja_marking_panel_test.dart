import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/services/secnja_marking_prefs.dart';
import 'package:gozdar/widgets/secnja_marking_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('sl'));

  group('nextSecnjaName', () {
    test('uses species and count', () {
      expect(nextSecnjaName(species: 'Smreka', existing: 2, l10n: l10n), 'Smreka 3');
    });
    test('falls back to Drevo', () {
      expect(nextSecnjaName(existing: 2, l10n: l10n), 'Drevo 3');
    });
  });

  test('SecnjaMarkingPrefs remembers species and clears with null', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SecnjaMarkingPrefs();
    expect(await prefs.getSpecies(), isNull);
    await prefs.setSpecies('Bukev');
    expect(await prefs.getSpecies(), 'Bukev');
    await prefs.setSpecies(null);
    expect(await prefs.getSpecies(), isNull);
  });

  Future<List<String>> pumpPanel(
    WidgetTester tester, {
    String? selected,
    bool canUndo = true,
    int count = 4,
  }) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SecnjaMarkingPanel(
              title: '🪓 Sečnja · 1234/5',
              count: count,
              species: const ['Smreka', 'Bukev', 'Jelka'],
              selectedSpecies: selected,
              onSpeciesSelected: (s) => calls.add('species:$s'),
              onAddSpecies: () => calls.add('add'),
              onUndo: canUndo ? () => calls.add('undo') : null,
              onMark: () => calls.add('mark'),
              onLocate: () => calls.add('locate'),
              onFinish: () => calls.add('finish'),
            ),
          ),
        ),
      ),
    );
    return calls;
  }

  testWidgets('tapping Označi calls onMark', (tester) async {
    final calls = await pumpPanel(tester);
    await tester.tap(find.text('Označi'));
    expect(calls, ['mark']);
  });

  testWidgets('undo disabled when onUndo is null', (tester) async {
    final calls = await pumpPanel(tester, canUndo: false);
    await tester.tap(find.text('Razveljavi'));
    expect(calls, isEmpty);
  });

  testWidgets('tapping a chip selects it; tapping the selected chip deselects',
      (tester) async {
    var calls = await pumpPanel(tester);
    await tester.tap(find.text('Bukev'));
    expect(calls, ['species:Bukev']);

    calls = await pumpPanel(tester, selected: 'Bukev');
    await tester.tap(find.text('Bukev'));
    expect(calls, ['species:null']);
  });

  testWidgets('header shows title and count', (tester) async {
    await pumpPanel(tester, count: 4);
    expect(find.text('🪓 Sečnja · 1234/5'), findsOneWidget);
    expect(find.text('4 drevesa'), findsOneWidget);
  });

  testWidgets('Končaj calls onFinish', (tester) async {
    final calls = await pumpPanel(tester);
    await tester.tap(find.text('Končaj'));
    expect(calls, ['finish']);
  });
}

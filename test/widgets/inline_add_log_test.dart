import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/widgets/inline_add_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('type → Dodaj → type loop stays inline and counts adds',
      (tester) async {
    final added = <LogEntry>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox()),
            InlineAddLog(onAdd: (e) async => added.add(e)),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Nothing entered: Dodaj disabled, hint shown.
    expect(find.text('Vnesi premer in dolžino'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Dodaj')).onPressed,
      isNull,
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Premer (cm)'), '40');
    await tester.enterText(find.widgetWithText(TextFormField, 'Dolžina (m)'), '4');
    await tester.pump();
    // V = π × (0.4/2)² × 4 = 0.5027 m³
    expect(find.text('0.5027 m³'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Dodaj'));
    await tester.pumpAndSettle();

    expect(added, hasLength(1));
    expect(added.single.volume, closeTo(0.5027, 0.0001));
    // Still on screen, counting, and the last values stay put so a run of
    // similar logs is just repeated "Dodaj".
    expect(find.text('Dodaj (+1)'), findsOneWidget);
    expect(find.text('0.5027 m³'), findsOneWidget);
    final diameter = tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, 'Premer (cm)'))
        .controller!;
    expect(diameter.text, '40');
    // Diameter is focused with its text selected so typing replaces it.
    expect(diameter.selection, const TextSelection(baseOffset: 0, extentOffset: 2));

    await tester.tap(find.widgetWithText(FilledButton, 'Dodaj (+1)'));
    await tester.pumpAndSettle();
    expect(added, hasLength(2));
    expect(find.text('Dodaj (+2)'), findsOneWidget);
  });

  testWidgets('last diameter and length survive a remount', (tester) async {
    Widget build() => MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                InlineAddLog(onAdd: (_) async {}),
              ],
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Premer (cm)'), '32.5');
    await tester.enterText(find.widgetWithText(TextFormField, 'Dolžina (m)'), '4');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Dodaj'));
    await tester.pumpAndSettle();

    // Fresh widget (e.g. after an app restart) is prefilled from the last add.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Premer (cm)'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Premer (cm)')).controller!.text,
      '32.5',
    );
    expect(
      tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Dolžina (m)')).controller!.text,
      '4',
    );
    expect(find.text('Dodaj'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Dodaj')).onPressed,
      isNotNull,
    );
  });

  testWidgets('species comes from the widget, not a dropdown', (tester) async {
    final added = <LogEntry>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox()),
            InlineAddLog(species: 'Bukev', onAdd: (e) async => added.add(e)),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Premer (cm)'), '40');
    await tester.enterText(find.widgetWithText(TextFormField, 'Dolžina (m)'), '4');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Dodaj'));
    await tester.pumpAndSettle();
    expect(added.single.species, 'Bukev');
  });
}

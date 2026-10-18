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
    // Still on screen, cleared, counting, ready for the next one.
    expect(find.text('Dodaj (+1)'), findsOneWidget);
    expect(find.text('0.5027 m³'), findsNothing);
    expect(
      tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Premer (cm)')).controller!.text,
      isEmpty,
    );
  });
}

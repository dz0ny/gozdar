import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/widgets/inline_add_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('type → Dodaj → type loop stays inline and counts adds', (
    tester,
  ) async {
    final added = <LogEntry>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              InlineAddLog(onAdd: (e) async => added.add(e)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing entered: the round "+" (= Dodaj) is disabled, no volume yet.
    expect(find.text('–'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextFormField).first, '40');
    await tester.enterText(find.byType(TextFormField).last, '4');
    await tester.pump();
    // V = π × (0.4/2)² × 4 = 0.5027 m³
    expect(find.text('0.503'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(added, hasLength(1));
    expect(added.single.volume, closeTo(0.5027, 0.0001));
    // Still on screen and counting. The length stays for the next log; the
    // diameter is cleared and focused, so the "+" waits for a new one.
    expect(find.text('Dodano: 1'), findsOneWidget);
    expect(find.text('0.503'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      '4',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextFormField).first, '30');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(added, hasLength(2));
    expect(added.last.diameter, 30);
    expect(added.last.length, 4);
    expect(find.text('Dodano: 2'), findsOneWidget);
  });

  testWidgets('last length survives a remount; diameter starts empty', (
    tester,
  ) async {
    Widget build() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sl'),
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
    await tester.enterText(find.byType(TextFormField).first, '32.5');
    await tester.enterText(find.byType(TextFormField).last, '4');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Fresh widget (e.g. after an app restart): length prefilled, diameter empty.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      '4',
    );
    expect(find.text('Dodano: 1'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('species comes from the widget, not a dropdown', (tester) async {
    final added = <LogEntry>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              InlineAddLog(species: 'Bukev', onAdd: (e) async => added.add(e)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, '40');
    await tester.enterText(find.byType(TextFormField).last, '4');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(added.single.species, 'Bukev');
  });
}

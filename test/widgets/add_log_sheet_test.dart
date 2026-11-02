import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/widgets/add_log_sheet.dart';
import 'package:latlong2/latlong.dart';

void main() {
  Future<Future<LogEntry?>> open(
    WidgetTester tester, {
    double? lastLength,
    String? species,
    VoidCallback? onBack,
  }) async {
    late Future<LogEntry?> result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = AddLogSheet.show(
                context: context,
                position: const LatLng(46.05, 14.5),
                parcelLabel: 'Parcela 1234',
                lastLength: lastLength,
                species: species,
                onBack: onBack,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('diameter and length save a located log with its volume', (
    tester,
  ) async {
    final result = await open(tester, species: 'Bukev');
    await tester.enterText(field('Premer'), '30');
    await tester.enterText(field('Dolžina'), '4');
    await tester.pump();
    expect(find.text('0,28 m³'), findsOneWidget);
    await tester.tap(find.text('Shrani'));
    await tester.pumpAndSettle();
    final log = (await result)!;
    expect(log.diameter, 30);
    expect(log.length, 4);
    expect(log.volume, closeTo(LogEntry.calculateVolume(30, 4), 1e-9));
    expect(log.latitude, 46.05);
    expect(log.longitude, 14.5);
    expect(log.species, 'Bukev');
  });

  testWidgets('the last length is prefilled and the diameter has focus', (
    tester,
  ) async {
    await open(tester, lastLength: 4.5);
    expect(tester.widget<TextField>(field('Dolžina')).controller!.text, '4.5');
    expect(tester.widget<TextField>(field('Premer')).autofocus, isTrue);
  });

  testWidgets('save is disabled until both values are valid', (tester) async {
    await open(tester);
    FilledButton save() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Shrani'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(save().onPressed, isNull);
    await tester.enterText(field('Premer'), '354');
    await tester.enterText(field('Dolžina'), '4');
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(field('Premer'), '35');
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  testWidgets('back closes the sheet and calls onBack', (tester) async {
    var backs = 0;
    final result = await open(tester, onBack: () => backs++);
    await tester.tap(find.byTooltip('Nazaj'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(backs, 1);
  });
}

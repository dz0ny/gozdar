import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/widgets/map_dialogs.dart';
import 'package:latlong2/latlong.dart';

typedef PointResult = ({String name, double latitude, double longitude});

void main() {
  Future<Future<PointResult?>> open(WidgetTester tester, {String? parcelLabel}) async {
    late Future<PointResult?> result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sl'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = MapDialogs.showAddLocationDialog(
                context: context,
                position: const LatLng(46.05, 14.5),
                nextNumber: 7,
                parcelLabel: parcelLabel,
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

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Shrani'));
    await tester.pumpAndSettle();
  }

  testWidgets('save without typing returns Točka 7', (tester) async {
    final result = await open(tester);
    await save(tester);
    expect((await result)!.name, 'Točka 7');
  });

  testWidgets('tapping Izvir returns Izvir', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Izvir'));
    await tester.pump();
    await save(tester);
    expect((await result)!.name, 'Izvir');
  });

  testWidgets('typed text wins over chips', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Izvir'));
    await tester.enterText(find.byType(TextField), 'Stara bukev');
    await tester.pump();
    await save(tester);
    expect((await result)!.name, 'Stara bukev');
  });

  testWidgets('keyboard does not open', (tester) async {
    await open(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isFalse);
    expect(field.focusNode?.hasFocus ?? false, isFalse);
  });

  testWidgets('no error text after save with empty field and no chip', (tester) async {
    final result = await open(tester);
    // Deselect the default chip.
    await tester.tap(find.text('Točka 7'));
    await tester.pump();
    await save(tester);
    expect(find.text('Vnesite ime'), findsNothing);
    expect((await result)!.name, 'Točka 7');
  });

  testWidgets('subtitle names the parcel', (tester) async {
    await open(tester, parcelLabel: 'Parcela 1234/5');
    expect(find.textContaining('Parcela 1234/5 · '), findsOneWidget);
  });
}

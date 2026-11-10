import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/services/owner_lookup_service.dart';
import 'package:gozdar/widgets/owner_list.dart';

void main() {
  const owner = 'ZAKLADA ZA MLADE';
  final info = OwnerInfo(
    owners: const [owner],
    holders: const [OwnerHolder(owner, share: '1/1')],
    koName: 'PREZID',
    sources: [
      OwnerSource(
        OwnerSourceKind.landRegistry,
        lrUnitNumber: '1876',
        place: 'PREZID',
        url: Uri.https(
          'oss.uredjenazemlja.hr',
          '/public-services/review-lr-bdc',
        ),
      ),
    ],
  );

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('sl'),
    home: Scaffold(body: child),
  );

  test('one owner with a source has details to show', () {
    expect(info.hasDetails, isTrue);
    expect(const OwnerInfo(owners: [owner]).hasDetails, isFalse);
    expect(const OwnerInfo(owners: [owner, 'B']).hasDetails, isTrue);
  });

  test('the web search for an owner uses the name and the address', () {
    expect(ownerSearchQuery(const OwnerHolder('NOVAK JANEZ')), 'NOVAK JANEZ');
    const full = OwnerHolder(
      'NOVAK JANEZ',
      share: '1/2',
      address: 'BABNO POLJE 12, Loška dolina',
    );
    // The share stays out of the query.
    expect(ownerSearchQuery(full), 'NOVAK JANEZ BABNO POLJE 12, Loška dolina');
    expect(
      ownerSearchUri(full).queryParameters['q'],
      'NOVAK JANEZ BABNO POLJE 12, Loška dolina',
    );
    expect(
      ownerSearchQuery(const OwnerHolder('NOVAK JANEZ', address: '  ')),
      'NOVAK JANEZ',
    );
  });

  testWidgets('the caption names the register', (tester) async {
    await tester.pumpWidget(app(OwnerSourceCaption(info: info)));
    expect(find.text('Vir: Zemljiška knjiga'), findsOneWidget);
  });

  testWidgets('no source, no caption', (tester) async {
    await tester.pumpWidget(
      app(const OwnerSourceCaption(info: OwnerInfo(owners: [owner]))),
    );
    expect(find.textContaining('Vir'), findsNothing);
  });

  testWidgets('a single owner sheet lists the owner and the linked source', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                OwnersSheet.show(context, owners: info.owners, info: info),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(owner), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Vir'), findsOneWidget);
    expect(find.text('Zemljiška knjiga'), findsOneWidget);
    expect(find.text('ZK vložek 1876, k.o. PREZID'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  testWidgets('a cadastre source says holders are not always owners', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const OwnerSourceTile(
          source: OwnerSource(OwnerSourceKind.cadastre, place: 'PREZID'),
        ),
      ),
    );
    expect(find.text('Kataster'), findsOneWidget);
    expect(
      find.text('Posestniki po katastru, niso nujno lastniki.'),
      findsOneWidget,
    );
    // No URL, no link icon.
    expect(find.byIcon(Icons.open_in_new), findsNothing);
  });
}

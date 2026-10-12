import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/owner_lookup_service.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds a small owners database and opens it in [OwnerLookupService].
String _openFixture(Directory dir) {
  final path = '${dir.path}/owners.sqlite';
  sqlite3.open(path)
    ..execute(
      'CREATE TABLE owners(sifko INT, parcela TEXT, lastnik TEXT, '
      'naslov TEXT, imeko TEXT, obcina TEXT)',
    )
    ..execute(
      "INSERT INTO owners VALUES "
      "(1651,'1234/2','NOVAK JANEZ','BABNO POLJE 12',  'BABNO POLJE',NULL),"
      "(1651,'1234/2','NOVAK MARIJA','BABNO POLJE 12', 'BABNO POLJE',NULL),"
      "(1651,'88',    'NOVAK JANEZ','BABNO POLJE 12',  'BABNO POLJE',NULL),"
      "(1700,'5',     'KOŠIR ŽIGA', 'ŠKOFJA LOKA 3',   'KOZARIŠČE', NULL),"
      "(1700,'6',     'JANKOVI?ć MILAN','ČRNOMELJ 1',  'KOZARIŠČE', NULL),"
      "(1700,'7',     'MAJ_50%',    NULL,              'KOZARIŠČE', NULL),"
      "(1700,'8',     'Šuštar Čedo', NULL,             'KOZARIŠČE', NULL),"
      "(1700,'9',     'ŠUŠTAR JANEZ', NULL,            'KOZARIŠČE', NULL),"
      "(1700,'10',    'SUSTAR ANA',  NULL,             'KOZARIŠČE', NULL)",
    )
    ..close();
  OwnerLookupService.instance.openForTesting(path);
  return path;
}

void main() {
  final service = OwnerLookupService.instance;

  // Every search case runs against the plain full scan and the trigram
  // index; both must give the same answers.
  for (final indexed in [false, true]) {
    group(indexed ? 'with search index' : 'without search index', () {
      late Directory dir;

      setUpAll(() async {
        dir = Directory.systemTemp.createTempSync('owners-');
        _openFixture(dir);
        if (indexed) await service.buildSearchIndexForTesting();
        expect(service.hasSearchIndex, indexed);
      });

      tearDownAll(() => dir.deleteSync(recursive: true));

      List<String> owners(String name, {String? address}) => service
          .searchOwners(name: name, address: address)
          .hits
          .map((h) => h.owner)
          .toList();

      test('co-owners of one parcel come back as a single hit', () {
        final result = service.searchOwners(name: 'novak');

        expect(result.truncated, isFalse);
        expect(result.hits.map((h) => h.parcela), ['1234/2', '88']);
        expect(result.hits.first.owners, ['NOVAK JANEZ', 'NOVAK MARIJA']);
        expect(result.hits.first.owner, 'NOVAK JANEZ, NOVAK MARIJA');
      });

      test('truncated is set when more parcels match than the limit', () {
        final result = service.searchOwners(name: 'novak', limit: 1);

        expect(result.hits, hasLength(1));
        expect(result.truncated, isTrue);
      });

      test('terms under 3 characters are not searched', () {
        expect(service.searchOwners(name: 'no').tooShort, isTrue);
        expect(service.searchOwners(name: 'no').hits, isEmpty);
        expect(
          service.searchOwners(name: 'novak', address: 'ba').tooShort,
          isTrue,
        );
        expect(service.searchOwners(name: 'nov').tooShort, isFalse);
      });

      test('plain letters find š/č/ž names and addresses', () {
        expect(owners('kosir'), ['KOŠIR ŽIGA']);
        expect(owners('ziga'), ['KOŠIR ŽIGA']);
        expect(service.searchOwners(address: 'skofja').hits, hasLength(1));
      });

      test('typing the diacritic still matches', () {
        expect(owners('košir'), ['KOŠIR ŽIGA']);
        expect(owners('KOŠIR'), ['KOŠIR ŽIGA']);
      });

      test('mangled source letters match both spellings', () {
        expect(owners('jankovic'), ['JANKOVIĆ MILAN']);
        expect(owners('janković'), ['JANKOVIĆ MILAN']);
        expect(service.searchOwners(address: 'crnomelj').hits, hasLength(1));
      });

      test('sustar and šustar find the same owners', () {
        const both = ['SUSTAR ANA', 'ŠUŠTAR JANEZ', 'Šuštar Čedo'];
        for (final q in ['sustar', 'šustar', 'ŠUŠTAR', 'Sustar']) {
          expect(owners(q)..sort(), both.toList()..sort(), reason: q);
        }
      });

      test('matches regardless of case in the data (ILIKE)', () {
        expect(owners('sustar ced'), ['Šuštar Čedo']);
        expect(owners('ŠUŠTAR ČEDO'), ['Šuštar Čedo']);
      });

      test('name and address combine', () {
        expect(owners('novak', address: 'babno'), [
          'NOVAK JANEZ, NOVAK MARIJA',
          'NOVAK JANEZ',
        ]);
        expect(owners('novak', address: 'skofja'), isEmpty);
      });

      test('% and _ in the query are literal', () {
        expect(owners('aj_50%'), ['MAJ_50%']);
        expect(owners('j_5'), ['MAJ_50%']);
      });

      test('searchOwnersAsync gives the same result off the UI isolate',
          () async {
        final result = await service.searchOwnersAsync(name: 'sustar');
        expect(result.hits, hasLength(3));
        expect((await service.searchOwnersAsync(name: 'su')).tooShort, isTrue);
      });
    });
  }
}

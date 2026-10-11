import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/owner_lookup_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('owners-');
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
        "(1700,'8',     'Šuštar Čedo', NULL,             'KOZARIŠČE', NULL)",
      )
      ..close();
    OwnerLookupService.instance.openForTesting(path);
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  test('co-owners of one parcel come back as a single hit', () {
    final result = OwnerLookupService.instance.searchOwners(name: 'novak');

    expect(result.truncated, isFalse);
    expect(result.hits.map((h) => h.parcela), ['1234/2', '88']);
    expect(result.hits.first.owners, ['NOVAK JANEZ', 'NOVAK MARIJA']);
    expect(result.hits.first.owner, 'NOVAK JANEZ, NOVAK MARIJA');
  });

  test('truncated is set when more parcels match than the limit', () {
    final result =
        OwnerLookupService.instance.searchOwners(name: 'novak', limit: 1);

    expect(result.hits, hasLength(1));
    expect(result.truncated, isTrue);
  });

  group('diacritic-insensitive search', () {
    List<String> owners(String name, {String? address}) => OwnerLookupService
        .instance
        .searchOwners(name: name, address: address)
        .hits
        .map((h) => h.owner)
        .toList();

    test('plain letters find š/č/ž names', () {
      expect(owners('kosir'), ['KOŠIR ŽIGA']);
      expect(owners('ziga'), ['KOŠIR ŽIGA']);
      expect(
        OwnerLookupService.instance.searchOwners(address: 'skofja').hits,
        hasLength(1),
      );
    });

    test('typing the diacritic still matches', () {
      expect(owners('košir'), ['KOŠIR ŽIGA']);
      expect(owners('KOŠIR'), ['KOŠIR ŽIGA']);
    });

    test('mangled source letters match both spellings', () {
      expect(owners('jankovic'), ['JANKOVIĆ MILAN']);
      expect(owners('janković'), ['JANKOVIĆ MILAN']);
      expect(
        OwnerLookupService.instance.searchOwners(address: 'crnomelj').hits,
        hasLength(1),
      );
    });

    test('matches regardless of case in the data (ILIKE)', () {
      expect(owners('sustar ced'), ['Šuštar Čedo']);
      expect(owners('ŠUŠTAR'), ['Šuštar Čedo']);
    });

    test('% and _ in the query are literal', () {
      expect(owners('maj_50%'), ['MAJ_50%']);
      expect(owners('%'), ['MAJ_50%']);
    });
  });
}

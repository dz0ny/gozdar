import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/address_lookup_service.dart';
import 'package:gozdar/services/ko_locator.dart';
import 'package:gozdar/services/parcel_search_service.dart';
import 'package:sqlite3/sqlite3.dart';

import '../fixtures/address_fixture.dart';

void main() {
  late Directory dir;
  final service = AddressLookupService.instance;

  setUpAll(() {
    KoLocator.instance.loadForTesting(
      File('test/fixtures/ko_index_small.json').readAsStringSync(),
    );
    dir = Directory.systemTemp.createTempSync('addresses_test');
    openAddressFixture(dir);
  });

  tearDownAll(() {
    service.closeForTesting();
    dir.deleteSync(recursive: true);
  });

  group('AddressLookupService', () {
    test('opens the fixture', () {
      expect(service.isAvailable, isTrue);
      expect(service.built, '2026-11-09T12:43:25Z');
      expect(service.rowCount, 7);
    });

    test('finds a house on a street by street name and number', () {
      final hits = service.search('Poljska ulica', '15');
      expect(hits, hasLength(1));
      expect(hits.single.title, 'Poljska ulica 15');
      expect(hits.single.subtitle, 'Kranj, 4000 Kranj');
      expect(hits.single.point.latitude, closeTo(46.24, 0.001));
      expect(hits.single.building, 9003);
    });

    test('matches word prefixes without diacritics', () {
      expect(service.search('sorl', '7').single.title, 'Šorlijeva ulica 7');
      expect(service.search('polj ul', '15'), hasLength(1));
    });

    test('finds a village house by settlement and number', () {
      final hits = service.search('Babno Polje', '12');
      expect(hits.single.title, 'Babno Polje 12');
      expect(hits.single.subtitle, '1386 Stari trg pri Ložu');
      expect(hits.single.municipality, 'Loška dolina');
    });

    test('upper-cases the letter suffix', () {
      expect(service.search('babno', '12a').single.number, '12A');
    });

    test('a settlement match lists only houses without a street', () {
      // "Kranj 12" must not list the 12 of every street in Kranj.
      expect(service.search('Kranj', '12'), isEmpty);
      expect(service.search('Kranj', '3').single.title, 'Kranj 3');
    });

    test('a street can be found with the help of its settlement', () {
      final hits = service.search('Kranj Poljska', '12');
      expect(hits.map((h) => h.title), ['Poljska ulica 12']);
    });

    test('rejects what cannot be a house number', () {
      expect(service.search('Poljska', '1234'), isEmpty);
      expect(service.search('Poljska', '12/3'), isEmpty);
      expect(service.search('', '12'), isEmpty);
    });

    test('suggests streets for typed words, own-name matches first', () {
      final streets = service.streets('ul');
      expect(streets.map((s) => s.name), [
        'Poljska ulica',
        'Jerebova ulica',
        'Šorlijeva ulica',
      ]);
      expect(streets.first.settlement, 'Kranj');
      expect(service.streets('x'), isEmpty);
    });
  });

  group('a street name that many settlements share', () {
    late Directory many;

    // 30 settlements with a "Dolga ulica 1" each; only the last is in the
    // BABNO POLJE of the KO fixture.
    setUpAll(() {
      many = Directory.systemTemp.createTempSync('addresses_many');
      final path = openAddressFixture(many);
      service.closeForTesting();
      final db = sqlite3.open(path);
      for (var i = 0; i < 30; i++) {
        final inBabno = i == 29;
        db
          ..execute("INSERT INTO settlements VALUES (?, ?, 2)", [
            1000 + i,
            'Vas ${i.toString().padLeft(2, '0')}',
          ])
          ..execute("INSERT INTO streets VALUES (?, 'Dolga ulica', ?)", [
            2000 + i,
            1000 + i,
          ])
          ..execute(
            "INSERT INTO addresses VALUES (?, '1', ?, ?, 20, ?, ?, NULL)",
            [
              3000 + i,
              2000 + i,
              1000 + i,
              inBabno ? 456550000 : 462400000 + i,
              inBabno ? 145550000 : 143550000,
            ],
          );
      }
      db.close();
      service.openForTesting(path);
    });

    tearDownAll(() {
      service.closeForTesting();
      many.deleteSync(recursive: true);
      service.openForTesting('${dir.path}/addresses.sqlite');
    });

    test('the house in the selected KO comes first', () {
      final babno = KoLocator.instance.bySifko(1651);
      final hits = service.search('Dolga ulica', '1', preferKo: babno);
      expect(hits, hasLength(10));
      expect(hits.first.settlement, 'Vas 29');
    });

    test('without a KO the order is the same on every run', () {
      final hits = service.search('Dolga ulica', '1', limit: 30);
      expect(hits, hasLength(30));
      expect(hits.map((h) => h.id), [for (var i = 0; i < 30; i++) 3000 + i]);
    });
  });

  group('ParcelSearchService.addresses', () {
    test('a number with words gives address rows', () {
      final rows = ParcelSearchService.addresses('Poljska ulica 15');
      expect(rows.single.kind, ParcelSuggestionKind.address);
      expect(rows.single.title, 'Poljska ulica 15');
      expect(rows.single.point, isNotNull);
    });

    test('the number may come first', () {
      expect(
        ParcelSearchService.addresses('12 Babno Polje').map((r) => r.title),
        ['Babno Polje 12'],
      );
    });

    test('words alone give street rows', () {
      final rows = ParcelSearchService.addresses('Jereb');
      expect(rows.single.kind, ParcelSuggestionKind.street);
      expect(rows.single.title, 'Jerebova ulica');
      expect(rows.single.subtitle, 'Kranj');
    });

    test('a parcel number is never an address', () {
      expect(ParcelSearchService.addresses('123/4 Babno'), isEmpty);
      expect(ParcelSearchService.addresses('Babno 1234'), isEmpty);
    });

    test('too short a query gives nothing', () {
      expect(ParcelSearchService.addresses('B 12'), isEmpty);
      expect(ParcelSearchService.addresses('12'), isEmpty);
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/ko_locator.dart';
import 'package:gozdar/services/parcel_search_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  KoLocator.instance.loadForTesting(
    File('test/fixtures/ko_index_small.json').readAsStringSync(),
  );

  final locator = KoLocator.instance;

  group('point lookup', () {
    test('finds the KO a point lies in', () {
      expect(locator.koAt(const LatLng(45.655, 14.555))?.sifko, 1651);
      expect(locator.koAt(const LatLng(45.655, 14.575))?.name, 'KOZARIŠČE');
    });

    test('snaps to a border within ~300 m, but not further', () {
      expect(locator.koAt(const LatLng(45.6502, 14.5603))?.sifko, 1651);
      expect(locator.koAt(const LatLng(45.9, 14.9)), isNull);
    });
  });

  group('name search', () {
    List<int> codes(String q) => locator.search(q).map((k) => k.sifko).toList();

    test('ignores case and diacritics', () {
      expect(codes('sentjur'), [2001]);
      expect(codes('ŠENT'), [2001]);
      expect(codes('kozarisce'), [1700]);
    });

    test('matches any word, and codes by prefix', () {
      expect(codes('trg'), [2002]);
      expect(codes('polje'), [1651]);
      expect(codes('165'), [1651]);
    });

    test('prefix matches rank before substring matches', () {
      expect(codes('babno'), [1651]);
      expect(codes('bno'), [1651]);
    });
  });

  group('suggestions', () {
    final babno = locator.bySifko(1651)!;

    test('parcel numbers like 123/4 are parsed from the words', () {
      final p = ParsedParcelQuery.parse('babno polje 123/4');
      expect(p.words, 'babno polje');
      expect(p.parcelNumber, '123/4');
      expect(ParsedParcelQuery.parse('novak').parcelNumber, isNull);
    });

    test('a number in the selected KO offers that parcel', () {
      final s = ParcelSearchService.instant('123/4', ko: babno);
      expect(s.first.kind, ParcelSuggestionKind.parcel);
      expect(s.first.title, 'Parcela 123/4');
      expect(s.first.subtitle, 'KO BABNO POLJE (1651)');
      expect(s.first.sifko, 1651);
    });

    test('KO name plus number offers the parcel in the matching KO', () {
      final s = ParcelSearchService.instant('sentjur 88');
      expect(s.single.kind, ParcelSuggestionKind.parcel);
      expect(s.single.sifko, 2001);
      expect(s.single.parcela, '88');
    });

    test('a bare number without a KO offers matching KO codes only', () {
      final s = ParcelSearchService.instant('165');
      expect(s.every((x) => x.kind == ParcelSuggestionKind.ko), isTrue);
      expect(s.map((x) => x.ko!.sifko), [1651]);
    });

    test('typing a KO name suggests the KO', () {
      final s = ParcelSearchService.instant('koz');
      expect(s.single.kind, ParcelSuggestionKind.ko);
      expect(s.single.title, 'KOZARIŠČE');
    });
  });
}

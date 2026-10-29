import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/ko_locator.dart';
import 'package:gozdar/services/parcel_search_service.dart';

void main() {
  KoLocator.instance.loadForTesting(
    File('test/fixtures/ko_index_small.json').readAsStringSync(),
  );

  List<(int?, String?)> parcels(String query, {KoInfo? ko}) => [
        for (final s in ParcelSearchService.instant(query, ko: ko))
          if (s.parcela != null) (s.sifko, s.parcela),
      ];

  group('ParcelSearchService.instant', () {
    test('"KO code, parcel" comes first, the other reading after', () {
      final found = parcels('1651 1700');
      expect(found.first, (1651, '1700'));
      expect(found, contains((1700, '1651')));
    });

    test('a typed KO code beats the selected KO', () {
      final selected = KoLocator.instance.bySifko(2001);
      final found = parcels('1651 1700', ko: selected);
      expect(found.first, (1651, '1700'));
      expect(found, contains((2001, '1651')));
    });

    test('KO code with a sub-parcel', () {
      expect(parcels('1651 12/3').first, (1651, '12/3'));
    });

    test('a first number that is no KO code is not read as one', () {
      expect(parcels('9999 1700'), isNot(contains((9999, '1700'))));
    });

    test('KO name with parcel still works', () {
      expect(parcels('12 Babno polje').first, (1651, '12'));
    });
  });
}

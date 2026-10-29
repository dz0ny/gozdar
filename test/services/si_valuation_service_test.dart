import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/si_valuation_service.dart';

void main() {
  group('SiValuationService.covers', () {
    test('Slovenian šifra KO only', () {
      expect(SiValuationService.covers(1650), isTrue);
      expect(SiValuationService.covers(304549), isFalse);
      expect(SiValuationService.covers(null), isFalse);
    });
  });

  group('SiValuationService.parse', () {
    test('forest parcel: value, €/m², forest factors and model date', () {
      final v = SiValuationService.parse(
        {
          'pcMid': 27374546,
          'koSifko': 1650,
          'parcela': '1000',
          'povrsina': 3500.0,
          'boniteta': 26,
          'rk': 11,
          'odprtost': 100,
        },
        [
          {
            'model': 'GOZ',
            'delezPov': 100.0,
            'posplosenaVrednost': 3190,
            'raven': '6/10',
            'napakaOpis': null,
            'idModelVer': 1171,
          },
        ],
        modelDates: {'1171': 1747133426000},
      );

      expect(v.total, 3190);
      expect(v.perSquareMeter, closeTo(0.91, 0.005));
      expect(v.isForest, isTrue);
      expect(v.boniteta, 26);
      expect(v.siteIndex, 11);
      expect(v.openness, 100);
      expect(v.parts.single.level, '6/10');
      expect(v.modelDate?.year, 2025);
      expect(v.gursUrl, endsWith('parcela_27374546'));
    });

    test('farmland drops forest factors, keeps boniteta', () {
      final v = SiValuationService.parse(
        {
          'pcMid': 134423270,
          'koSifko': 1650,
          'parcela': '200/1',
          'povrsina': 138.0,
          'boniteta': 43,
          'rk': 5,
          'odprtost': 50,
        },
        [
          {'model': 'KME', 'delezPov': 100.0, 'posplosenaVrednost': 190},
        ],
      );

      expect(v.isForest, isFalse);
      expect(v.boniteta, 43);
      expect(v.siteIndex, isNull);
      expect(v.openness, isNull);
      expect(v.modelDate, isNull);
    });

    test('land under a building is left out of the total and €/m²', () {
      final v = SiValuationService.parse(
        {'pcMid': 1, 'koSifko': 1723, 'parcela': '500', 'povrsina': 1000.0},
        [
          {'model': 'STZ', 'delezPov': 60.0, 'posplosenaVrednost': 120000},
          {'model': 'ZPS', 'delezPov': 40.0, 'posplosenaVrednost': 0},
        ],
      );

      expect(v.total, 120000);
      expect(v.valuedArea, 600);
      expect(v.perSquareMeter, 200);
      expect(v.isUnvalued, isFalse);
    });

    test('a row GURS could not calculate counts as unvalued', () {
      final v = SiValuationService.parse(
        {'pcMid': 1, 'koSifko': 1650, 'parcela': '1', 'povrsina': 100.0},
        [
          {
            'model': 'DRZ',
            'delezPov': 100.0,
            'posplosenaVrednost': 50,
            'napakaOpis': 'Ni podatka',
          },
        ],
      );

      expect(v.total, 0);
      expect(v.isUnvalued, isTrue);
      expect(v.perSquareMeter, isNull);
    });
  });
}

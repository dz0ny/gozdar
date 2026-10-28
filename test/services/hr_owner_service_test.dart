import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/hr_owner_service.dart';
import 'package:gozdar/services/owner_lookup_service.dart';
import 'package:gozdar/widgets/owner_list.dart';

void main() {
  group('HrOwnerService.isCroatianKo', () {
    test('six-digit matični broj is Croatian, šifra KO is not', () {
      expect(HrOwnerService.isCroatianKo(304549), isTrue);
      expect(HrOwnerService.isCroatianKo(1651), isFalse);
      expect(HrOwnerService.isCroatianKo(null), isFalse);
    });
  });

  group('HrOwnerService.parseParcelInfo', () {
    test('collects holders across sheets, skips the unknown address', () {
      final info = HrOwnerService.parseParcelInfo({
        'cadMunicipalityName': 'DELNICE',
        'possessionSheets': [
          {
            'possessors': [
              {
                'name': 'HORVAT IVA',
                'ownership': '1/2',
                'address': 'NEPOZNATO BORAVIŠTE',
              },
              {
                'name': 'Marko Kovač',
                'ownership': '1/2',
                'address': 'ULICA 1, 51300 DELNICE',
              },
            ],
          },
          {
            'possessors': [
              {'name': 'HORVAT IVA', 'ownership': '1/1', 'address': ''},
            ],
          },
        ],
      });

      expect(info, isNotNull);
      expect(info!.owners, ['HORVAT IVA', 'Marko Kovač']);
      expect(info.address, 'ULICA 1, 51300 DELNICE');
      expect(info.koName, 'DELNICE');
      expect(info.holder('HORVAT IVA').share, '1/2');
      expect(info.holder('HORVAT IVA').address, isNull);
      expect(info.holder('Marko Kovač').address, 'ULICA 1, 51300 DELNICE');
    });

    test('no holders gives null', () {
      expect(HrOwnerService.parseParcelInfo({'possessionSheets': []}), isNull);
      expect(HrOwnerService.parseParcelInfo({}), isNull);
    });
  });

  group('owner list', () {
    test('split undoes displayOwners and drops blanks', () {
      const info = OwnerInfo(owners: ['A B', 'C D']);
      expect(OwnerInfo.split(info.displayOwners), ['A B', 'C D']);
      expect(OwnerInfo.split(' A •  • B '), ['A', 'B']);
      expect(OwnerInfo.split(null), isEmpty);
    });

    test('summary names the first owner and counts the rest', () {
      expect(ownerSummary(['A']), 'A');
      expect(ownerSummary(['A', 'B', 'C']), 'A in še 2');
      expect(ownerSummary([]), '');
    });

    test('holder falls back to a bare name', () {
      const info = OwnerInfo(owners: ['A']);
      expect(info.holder('A').name, 'A');
      expect(info.holder('A').share, isNull);
    });
  });
}

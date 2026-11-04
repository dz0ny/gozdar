import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/services/database_service.dart';
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

  group('HrOwnerService ZK owners', () {
    // Prezid 1: the cadastre still lists the old holder, the ZK the owner.
    final prezidParcel = <String, dynamic>{
      'cadMunicipalityName': 'PREZID',
      'possessionSheets': [
        {
          'possessors': [
            {
              'name': 'FINVEST CORP D.D. ZA PROIZVODNJU, TRGOVINU I USLUGE',
              'ownership': '1/1',
              'address': 'PREZID',
            },
          ],
        },
      ],
      'parcelLinks': [
        {
          'parcelNumber': '1',
          'lrUnit': {
            'lrUnitNumber': '1876',
            'mainBookId': 30978,
            'status': '0',
          },
        },
      ],
      'lrUnitsFromParcelLinks': [
        {'lrUnitNumber': '1876', 'mainBookId': 30978, 'status': '0'},
      ],
    };

    test('units come from the parcel links, once each', () {
      expect(HrOwnerService.lrUnitsOf(prezidParcel), [
        (mainBookId: 30978, lrUnitNumber: '1876'),
      ]);
      expect(HrOwnerService.lrUnitsOf({}), isEmpty);
      expect(
        HrOwnerService.lrUnitsOf({
          'lrUnitsFromParcelLinks': [
            {'lrUnitNumber': '5', 'mainBookId': 1, 'status': '1'},
          ],
        }),
        isEmpty,
      );
    });

    test('share comes from the description', () {
      expect(HrOwnerService.shareOf('1. Vlasnički dio: 1/2'), '1/2');
      expect(HrOwnerService.shareOf('6. Suvlasnički dio: 1/2'), '1/2');
      expect(
        HrOwnerService.shareOf('2. Suvlasnički dio: 1,71/100 ETAŽNO'),
        '1,71/100',
      );
      expect(HrOwnerService.shareOf('3.1. Suvlasnički dio etaže: 3/6'), '3/6');
      expect(
        HrOwnerService.shareOf('3. Suvlasnički dio s neodređenim omjerom'),
        isNull,
      );
      expect(HrOwnerService.shareOf(null), isNull);
    });

    test('ZK owner replaces the cadastre holder (Prezid 1)', () {
      final info = HrOwnerService.parseLrUnits([
        {
          'ownershipSheetB': {
            'lrUnitShares': [
              {
                'description': '1. Vlasnički dio: 1/1',
                'status': 1,
                'lrOwners': [
                  {'name': 'FINVEST CORP D.D.', 'address': ''},
                ],
                'subSharesAndEntries': [],
              },
              {
                'description': '2. Vlasnički dio: 1/1',
                'status': 0,
                'lrOwners': [
                  {
                    'name':
                        'ZAKLADA ZA MLADE BEZ RODITELJSKE SKRBI '
                        '"DR.SC. IVICA KRIŽ"',
                    'address': 'ZAGREB',
                  },
                ],
                'subSharesAndEntries': [],
              },
            ],
          },
        },
      ], prezidParcel);

      expect(info, isNotNull);
      expect(info!.owners, [
        'ZAKLADA ZA MLADE BEZ RODITELJSKE SKRBI "DR.SC. IVICA KRIŽ"',
      ]);
      expect(info.holders.single.share, '1/1');
      expect(info.holders.single.address, 'ZAGREB');
      expect(info.koName, 'PREZID');
    });

    test('sub-shares, entries and the cadastre address', () {
      final info = HrOwnerService.parseLrUnits(
        [
          {
            'ownershipSheetB': {
              'lrUnitShares': [
                {
                  'description': '2. Suvlasnički dio: 1,71/100 ETAŽNO (E-2)',
                  'status': 0,
                  'lrOwners': [],
                  'subSharesAndEntries': [
                    {
                      'description': '2.3. Suvlasnički dio etaže: 1/2',
                      'status': 0,
                      'lrOwners': [
                        {'name': 'Horvat Iva', 'address': ''},
                      ],
                    },
                    {
                      'description': '2.4. Suvlasnički dio etaže: 1/2',
                      'status': 0,
                      'lrOwners': [
                        {'name': 'Kovač Marko', 'address': 'Ulica 2, Zagreb'},
                      ],
                    },
                    {
                      'description': 'Zaprimljeno 05.04.2016. ZABILJEŽBA',
                      'status': null,
                      'lrOwners': [],
                    },
                  ],
                },
                {
                  'description': '3. Suvlasnički dio: 1/4',
                  'status': 0,
                  'lrOwners': [
                    {'name': 'Horvat Iva', 'address': ''},
                  ],
                },
              ],
            },
          },
        ],
        {
          'possessionSheets': [
            {
              'possessors': [
                {
                  'name': 'HORVAT IVA',
                  'ownership': '1/1',
                  'address': 'Ulica 1, Zagreb',
                },
              ],
            },
          ],
        },
      );

      expect(info!.owners, ['Horvat Iva', 'Kovač Marko']);
      expect(info.holder('Horvat Iva').share, '1/2 + 1/4');
      expect(info.holder('Horvat Iva').address, 'Ulica 1, Zagreb');
      expect(info.holder('Kovač Marko').share, '1/2');
      expect(info.address, 'Ulica 1, Zagreb');
    });

    test('no ZK owners gives null so the cadastre is used', () {
      expect(HrOwnerService.parseLrUnits([{}], prezidParcel), isNull);
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

  group('HrOwnerService.searchCached', () {
    setUp(() async {
      DatabaseService().setDatabaseForTesting(
        AppDatabase(NativeDatabase.memory()),
      );
      await HrOwnerService.instance.debugStore({
        '302759/100/1': {
          'koName': 'PREZID',
          'address': 'PREZID 12, 51303 PLEŠCE',
          'holders': [
            {'name': 'KOVAČIĆ ANTE', 'share': '1/1', 'address': 'PREZID 12'},
          ],
        },
        '304549/55': {
          'koName': 'DELNICE',
          'address': null,
          'holders': [
            {'name': 'HORVAT IVA', 'share': '1/2', 'address': null},
          ],
        },
      });
    });

    tearDown(() => DatabaseService().resetForTesting());

    test('a typed % or _ is not a wildcard', () async {
      expect(await HrOwnerService.instance.searchCached(['ko%']), isEmpty);
      expect(await HrOwnerService.instance.searchCached(['h_rvat']), isEmpty);
    });

    test(
      'finds a parcel by holder name, ignoring case and diacritics',
      () async {
        final hits = await HrOwnerService.instance.searchCached(['kovacic']);
        expect(hits, hasLength(1));
        expect(hits.single.sifko, 302759);
        expect(hits.single.parcela, '100/1');
      },
    );

    test('every word must match name, address or KO', () async {
      expect(
        await HrOwnerService.instance.searchCached(['ante', 'prezid']),
        hasLength(1),
      );
      expect(
        await HrOwnerService.instance.searchCached(['horvat', 'prezid']),
        isEmpty,
      );
    });

    test('restricts to one KO and ignores short words', () async {
      expect(
        await HrOwnerService.instance.searchCached([
          'horvat',
        ], onlySifko: 302759),
        isEmpty,
      );
      expect(await HrOwnerService.instance.searchCached(['ho']), isEmpty);
    });
  });
}

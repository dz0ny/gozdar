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
        "(1651,'88',    'NOVAK JANEZ','BABNO POLJE 12',  'BABNO POLJE',NULL)",
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
}

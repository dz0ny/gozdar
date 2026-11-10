import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/owner_lookup_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('owner-holders-');
    final path = '${dir.path}/owners.sqlite';
    sqlite3.open(path)
      ..execute(
        'CREATE TABLE owners(sifko INT, parcela TEXT, lastnik TEXT, '
        'naslov TEXT, imeko TEXT, obcina TEXT)',
      )
      ..execute(
        "INSERT INTO owners VALUES "
        "(1651,'10','NOVAK JANEZ','BABNO POLJE 12','BABNO POLJE','LOŠKA DOLINA'),"
        "(1651,'10','KOVAČ ANA','CESTA 5, 1000 LJUBLJANA','BABNO POLJE',NULL),"
        "(1651,'10','ZUPAN MIHA',NULL,'BABNO POLJE',NULL)",
      )
      ..close();
    OwnerLookupService.instance.openForTesting(path);
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  test('each Slovenian owner carries the address of that owner', () {
    final info = OwnerLookupService.instance.lookup(1651, '10')!;
    expect(info.owners, ['NOVAK JANEZ', 'KOVAČ ANA', 'ZUPAN MIHA']);
    expect(info.holder('NOVAK JANEZ').address, 'BABNO POLJE 12, LOŠKA DOLINA');
    expect(info.holder('KOVAČ ANA').address, 'CESTA 5, 1000 LJUBLJANA');
    expect(info.holder('ZUPAN MIHA').address, isNull);
    // The parcel-level address stays the first one found.
    expect(info.address, 'BABNO POLJE 12, LOŠKA DOLINA');
  });
}

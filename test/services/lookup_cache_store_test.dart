import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/services/database_service.dart';
import 'package:gozdar/services/lookup_cache_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => DatabaseService().setDatabaseForTesting(
      AppDatabase(NativeDatabase.memory()),
    ),
  );
  tearDown(() => DatabaseService().resetForTesting());

  test('writes, reads and replaces an answer', () async {
    final store = LookupCacheStore('t', version: 1);
    expect(await store.read('a'), isNull);
    await store.write('a', {'n': 1});
    await store.write('a', {'n': 2});
    expect(await store.read('a'), {'n': 2});
    expect(await store.all(), hasLength(1));
  });

  test('a new version drops the rows of older ones', () async {
    final v1 = LookupCacheStore('t', version: 1);
    await v1.write('a', {'n': 1});
    await LookupCacheStore('other', version: 1).write('a', {'n': 9});

    final v2 = LookupCacheStore('t', version: 2);
    expect(await v2.read('a'), isNull);
    v1.debugReset();
    expect(await v1.read('a'), isNull);
    expect(await LookupCacheStore('other', version: 1).read('a'), {'n': 9});
  });

  test('keepNewest trims the oldest answers', () async {
    final store = LookupCacheStore('t', version: 1);
    for (var i = 0; i < 5; i++) {
      // All in the same second: insertion order breaks the tie.
      await store.write('$i', {'n': i});
    }
    await store.keepNewest(2);
    expect([for (final r in await store.all()) r.key], ['3', '4']);
  });

  test(
    'search needs every term, honours the key prefix, no wildcards',
    () async {
      final store = LookupCacheStore('t', version: 1);
      await store.write('1/1', {}, search: 'horvat iva zagreb');
      await store.write('2/5', {}, search: 'horvat marko');
      await store.write('1%/9', {}, search: 'kovac');

      expect(await store.search(['horvat']), hasLength(2));
      expect(await store.search(['horvat', 'zagreb']), hasLength(1));
      expect(await store.search(['horvat'], keyPrefix: '2/'), hasLength(1));
      expect(await store.search(['h_rvat']), isEmpty);
      expect(await store.search(['kovac'], keyPrefix: '1/'), isEmpty);
      expect(await store.search(['kovac'], keyPrefix: '1%/'), hasLength(1));
    },
  );

  test('without a database nothing is read or kept', () async {
    await DatabaseService().resetForTesting();
    final store = LookupCacheStore('t', version: 1);
    await store.write('a', {'n': 1});
    expect(await store.read('a'), isNull);
    expect(await store.all(), isEmpty);
  });
}

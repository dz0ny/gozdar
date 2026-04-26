import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/services/database_service.dart';
import 'package:gozdar/services/offline_tile_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  final cache = OfflineTileCacheService.instance;
  final databaseService = DatabaseService();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline-tile-cache-test-');
    db = AppDatabase(NativeDatabase.memory());
    databaseService.setDatabaseForTesting(db);
    cache.resetForTesting();
    cache.setBaseDirForTesting(tempDir.path);
  });

  tearDown(() async {
    cache.resetForTesting();
    await databaseService.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('OfflineTileCacheService', () {
    test('stores and returns raw tile bytes without conversion', () async {
      const styleHash = 'style01';
      final bytes = Uint8List.fromList(List<int>.generate(32, (i) => i));

      await cache.saveStyleMeta(
        styleHash,
        displayName: 'Test layer',
        urlTemplate: 'https://tiles.example.com/{z}/{x}/{y}.png',
      );
      await cache.putTile(
        styleHash,
        12,
        1200,
        800,
        bytes,
        contentType: 'image/png',
        sourceUrl: 'https://tiles.example.com/12/1200/800.png',
      );

      final tile = await cache.getTileData(styleHash, 12, 1200, 800);
      final styles = await cache.listStylesDetailed();

      expect(tile, isNotNull);
      expect(tile!.bytes, orderedEquals(bytes));
      expect(tile.contentType, 'image/png');
      expect(await cache.hasTile(styleHash, 12, 1200, 800), isTrue);
      expect(styles, hasLength(1));
      expect(styles.single.tileCount, 1);
      expect(styles.single.sizeBytes, bytes.length);

      final file = File('${tempDir.path}/$styleHash/12/1200/800.png');
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), orderedEquals(bytes));
    });

    test('serves warm reads from memory cache', () async {
      const styleHash = 'style02';
      final bytes = Uint8List.fromList(List<int>.generate(64, (i) => 255 - i));

      await cache.saveStyleMeta(
        styleHash,
        displayName: 'Warm layer',
        urlTemplate: 'https://tiles.example.com/{z}/{x}/{y}.png',
      );
      await cache.putTile(
        styleHash,
        10,
        10,
        10,
        bytes,
        contentType: 'image/png',
        sourceUrl: 'https://tiles.example.com/10/10/10.png',
      );

      final firstRead = await cache.getTileData(styleHash, 10, 10, 10);
      expect(firstRead, isNotNull);

      final file = File('${tempDir.path}/$styleHash/10/10/10.png');
      await file.delete();

      final secondRead = await cache.getTileData(styleHash, 10, 10, 10);
      expect(secondRead, isNotNull);
      expect(secondRead!.bytes, orderedEquals(bytes));
      expect(secondRead.contentType, 'image/png');
    });

    test('hydrates existing on-disk tiles into sqlite metadata', () async {
      const styleHash = 'style03';
      final styleDir = Directory('${tempDir.path}/$styleHash/9/20');
      await styleDir.create(recursive: true);
      final file = File('${styleDir.path}/30.webp');
      final bytes = Uint8List.fromList(utf8.encode('raw-webp-like-bytes'));
      await file.writeAsBytes(bytes, flush: true);
      await File('${tempDir.path}/$styleHash/meta.json').writeAsString(
        jsonEncode({
          'displayName': 'Hydrated layer',
          'urlTemplate': 'https://tiles.example.com/{z}/{x}/{y}.webp',
        }),
        flush: true,
      );

      final styles = await cache.listStylesDetailed();
      final tiles = await cache.listTilesForStyle(styleHash);
      final tile = await cache.getTileData(styleHash, 9, 20, 30);

      expect(styles, hasLength(1));
      expect(styles.single.hash, styleHash);
      expect(styles.single.displayName, 'Hydrated layer');
      expect(styles.single.tileCount, 1);
      expect(styles.single.sizeBytes, bytes.length);
      expect(tiles, hasLength(1));
      expect(tiles.single.z, 9);
      expect(tiles.single.x, 20);
      expect(tiles.single.y, 30);
      expect(tile, isNotNull);
      expect(tile!.bytes, orderedEquals(bytes));
      expect(tile.contentType, 'image/webp');
    });

    test('drops stale sqlite rows when tile file is missing', () async {
      const styleHash = 'style04';
      final bytes = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));

      await cache.saveStyleMeta(
        styleHash,
        displayName: 'Stale layer',
        urlTemplate: 'https://tiles.example.com/{z}/{x}/{y}.png',
      );
      await cache.putTile(
        styleHash,
        7,
        8,
        9,
        bytes,
        contentType: 'image/png',
        sourceUrl: 'https://tiles.example.com/7/8/9.png',
      );

      cache.clearMemoryCacheForTesting();
      await File('${tempDir.path}/$styleHash/7/8/9.png').delete();

      final tile = await cache.getTileData(styleHash, 7, 8, 9);

      expect(tile, isNull);
      expect(await cache.hasTile(styleHash, 7, 8, 9), isFalse);
      expect(await cache.getCacheSize(), 0);
    });
  });
}

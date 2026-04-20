// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/services/database_service.dart';
import 'package:gozdar/services/offline_tile_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profiles cold and warm offline tile reads', () async {
    final tempDir = await Directory.systemTemp.createTemp('offline-tile-cache-profile-');
    final db = AppDatabase(NativeDatabase.memory());
    final databaseService = DatabaseService();
    final cache = OfflineTileCacheService.instance;

    databaseService.setDatabaseForTesting(db);
    cache.resetForTesting();
    cache.setBaseDirForTesting(tempDir.path);

    const styleHash = 'profile01';
    const tileCount = 1500;
    final payload = Uint8List.fromList(List<int>.generate(12 * 1024, (i) => i % 251));

    await cache.saveStyleMeta(
      styleHash,
      displayName: 'Profile layer',
      urlTemplate: 'https://tiles.example.com/{z}/{x}/{y}.png',
    );

    for (var i = 0; i < tileCount; i++) {
      final z = 14;
      final x = 4000 + (i % 50);
      final y = 2500 + (i ~/ 50);
      await cache.putTile(
        styleHash,
        z,
        x,
        y,
        payload,
        contentType: 'image/png',
        sourceUrl: 'https://tiles.example.com/$z/$x/$y.png',
      );
    }

    cache.clearMemoryCacheForTesting();
    final coldReadWatch = Stopwatch()..start();
    for (var i = 0; i < tileCount; i++) {
      final z = 14;
      final x = 4000 + (i % 50);
      final y = 2500 + (i ~/ 50);
      await cache.getTileData(styleHash, z, x, y);
    }
    coldReadWatch.stop();

    final warmReadWatch = Stopwatch()..start();
    for (var i = 0; i < tileCount; i++) {
      final z = 14;
      final x = 4000 + (i % 50);
      final y = 2500 + (i ~/ 50);
      await cache.getTileData(styleHash, z, x, y);
    }
    warmReadWatch.stop();

    final stats = await cache.listStylesDetailed();
    final speedup = coldReadWatch.elapsedMicroseconds / warmReadWatch.elapsedMicroseconds;

    print('offline_tile_cache_profile '
        'tiles=$tileCount '
        'bytes_per_tile=${payload.length} '
        'cold_read_ms=${coldReadWatch.elapsedMilliseconds} '
        'warm_read_ms=${warmReadWatch.elapsedMilliseconds} '
        'speedup=${speedup.toStringAsFixed(2)}x '
        'indexed_tile_count=${stats.single.tileCount} '
        'indexed_size_bytes=${stats.single.sizeBytes}');

    expect(stats.single.tileCount, tileCount);
    expect(stats.single.sizeBytes, tileCount * payload.length);

    cache.resetForTesting();
    await databaseService.resetForTesting();
    await tempDir.delete(recursive: true);
  });
}

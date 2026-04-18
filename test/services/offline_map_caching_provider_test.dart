import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/offline_map_caching_provider.dart';

void main() {
  group('OfflineMapCachingProvider', () {
    test('parses xyz tile urls with extension', () {
      final coords = OfflineMapCachingProvider.parseTileUrlForTesting(
        'https://tile.openstreetmap.org/12/2200/1450.png',
      );

      expect(coords, isNotNull);
      expect(coords?.z, 12);
      expect(coords?.x, 2200);
      expect(coords?.y, 1450);
    });

    test('parses query-style tile urls', () {
      final coords = OfflineMapCachingProvider.parseTileUrlForTesting(
        'https://example.com/tiles?x=2200&y=1450&z=12',
      );

      expect(coords, isNotNull);
      expect(coords?.z, 12);
      expect(coords?.x, 2200);
      expect(coords?.y, 1450);
    });

    test('extracts xyz template from path tile url', () {
      final template = OfflineMapCachingProvider.extractUrlTemplateForTesting(
        'https://tile.openstreetmap.org/12/2200/1450.png',
      );

      expect(template, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    });

    test('extracts xyz template from query tile url', () {
      final template = OfflineMapCachingProvider.extractUrlTemplateForTesting(
        'https://example.com/tiles?x=2200&y=1450&z=12',
      );

      expect(template, 'https://example.com/tiles?x={x}&y={y}&z={z}');
    });
  });
}

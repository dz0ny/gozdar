import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/models/map_layer.dart';
import 'package:gozdar/services/map_preferences_service.dart';

void main() {
  group('MapLayer.resolveUrlTemplate', () {
    test('keeps direct xyz layers unchanged', () {
      final template = MapLayer.openStreetMap.resolveUrlTemplate(
        MapPreferencesService.defaultWorkerUrl,
      );

      expect(template, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    });

    test('resolves kataster through the worker proxy', () {
      final template = MapLayer.kataster.resolveUrlTemplate(
        MapPreferencesService.defaultWorkerUrl,
      );

      expect(
        template,
        '${MapPreferencesService.defaultWorkerUrl}/tiles/kataster/{z}/{x}/{y}.png',
      );
    });

    test('returns null for proxy-only layers without a worker url', () {
      final template = MapLayer.kataster.resolveUrlTemplate(null);

      expect(template, isNull);
    });
  });
}

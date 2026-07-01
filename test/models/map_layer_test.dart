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

    test('resolves overlay layers through the worker proxy', () {
      final template = MapLayer.sestoji.resolveUrlTemplate(
        MapPreferencesService.defaultWorkerUrl,
      );

      expect(
        template,
        '${MapPreferencesService.defaultWorkerUrl}/tiles/sestoji/{z}/{x}/{y}.png',
      );
    });

    test('resolves layers with legacy enum names to worker slugs', () {
      expect(
        MapLayer.odsekiGozdni.resolveUrlTemplate(
          MapPreferencesService.defaultWorkerUrl,
        ),
        '${MapPreferencesService.defaultWorkerUrl}/tiles/odseki/{z}/{x}/{y}.png',
      );
      expect(
        MapLayer.katastrskObcine.resolveUrlTemplate(
          MapPreferencesService.defaultWorkerUrl,
        ),
        '${MapPreferencesService.defaultWorkerUrl}/tiles/katastrske-obcine/{z}/{x}/{y}.png',
      );
      expect(
        MapLayer.hisnestevilke.resolveUrlTemplate(
          MapPreferencesService.defaultWorkerUrl,
        ),
        '${MapPreferencesService.defaultWorkerUrl}/tiles/hisne-stevilke/{z}/{x}/{y}.png',
      );
    });

    test('returns null for proxy-only layers without a worker url', () {
      final template = MapLayer.kataster.resolveUrlTemplate(null);

      expect(template, isNull);
    });

    test(
      'caps native and download zoom at 19 while keeping app zoom at 22',
      () {
        expect(MapLayer.appMaxZoom, 22);
        expect(MapLayer.esriWorldImagery.nativeMaxZoom, 19);
        expect(MapLayer.esriWorldImagery.downloadMaxZoom, 19);
        expect(MapLayer.openTopoMap.nativeMaxZoom, 19);
        expect(MapLayer.openTopoMap.downloadMaxZoom, 19);
      },
    );
  });
}

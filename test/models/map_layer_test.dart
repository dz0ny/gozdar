import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/models/map_layer.dart';
import 'package:latlong2/latlong.dart';
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

    test('requests Croatian DGU layers directly, without the worker', () {
      final template = MapLayer.hrKataster.resolveUrlTemplate(null);

      expect(template, startsWith('https://wms1-gs-oss.uredjenazemlja.hr/'));
      expect(template, contains('LAYERS=oss%3ABZP_CESTICE'));
      expect(template, contains('STYLES=jis_cestice_kathr'));
      expect(template, contains('SRS=EPSG%3A3857'));
      expect(template, endsWith('&BBOX={bbox}'));
    });

    test('computes EPSG:3857 tile bounds', () {
      expect(
        MapLayer.webMercatorTileBbox(0, 0, 0),
        '-20037508.34,-20037508.34,20037508.34,20037508.34',
      );
      // z1 top-left quarter.
      expect(
        MapLayer.webMercatorTileBbox(1, 0, 0),
        '-20037508.34,0.00,0.00,20037508.34',
      );
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

  group('Croatian orthophotos', () {
    const worker = MapPreferencesService.defaultWorkerUrl;

    test('are direct EPSG:4326 GetMaps as transparent PNG', () {
      final t = MapLayer.hrDof2019.resolveUrlTemplate(worker)!;
      expect(
        t,
        startsWith(
          'https://geoportal.dgu.hr/services/inspire/orthophoto_2019_2020/wms?',
        ),
      );
      expect(t, contains('VERSION=1.3.0'));
      expect(t, contains('CRS=EPSG%3A4326'));
      expect(t, contains('FORMAT=image%2Fpng'));
      expect(t, contains('TRANSPARENT=TRUE'));
      expect(t, endsWith('&BBOX={bbox4326}'));
      expect(MapLayer.hrDof2019.isSlovenian, isFalse);
      expect(MapLayer.hrDof2019.isDirectWms, isTrue);
    });

    test('the tile box is lat,lon in WMS 1.3.0 order', () {
      // Prezid, z15: the tile checked against the DGU service.
      expect(
        MapLayer.geographicTileBbox(15, 17710, 11704),
        '45.63708710,14.56787109,45.64476822,14.57885742',
      );
      final url = MapLayer.fillTileBbox(
        MapLayer.hrDof2023.resolveUrlTemplate(worker)!,
        15,
        17710,
        11704,
      );
      expect(url, isNot(contains('{bbox')));
      expect(
        url,
        endsWith('BBOX=45.63708710,14.56787109,45.64476822,14.57885742'),
      );
    });

    test('each orthophoto is drawn with the other country\'s', () {
      // Slovenian underneath (white outside Slovenia), Croatian on top
      // (transparent outside Croatia), whichever was picked. Slovenian ones
      // pair with the unstamped 2019/20.
      for (final si in [
        MapLayer.ortofoto,
        MapLayer.ortofoto2023,
        MapLayer.ortofoto2022,
      ]) {
        expect(MapLayer.stackFor(si), [si, MapLayer.hrDof2019]);
      }
      expect(MapLayer.stackFor(MapLayer.hrDof2023), [
        MapLayer.ortofoto,
        MapLayer.hrDof2023,
      ]);
      expect(MapLayer.stackFor(MapLayer.hrDof2021), [
        MapLayer.ortofoto2022,
        MapLayer.hrDof2021,
      ]);
      expect(MapLayer.stackFor(MapLayer.hrDof2019), [
        MapLayer.ortofoto2022,
        MapLayer.hrDof2019,
      ]);
      expect(MapLayer.stackFor(MapLayer.openStreetMap), [
        MapLayer.openStreetMap,
      ]);
      expect(MapLayer.stackFor(MapLayer.dofIr), [MapLayer.dofIr]);
    });

    test('a partner asks for no tiles outside its country\'s box', () {
      final hr = MapLayer.hrDof2019.orthoCoverage!;
      final si = MapLayer.ortofoto.orthoCoverage!;
      const split = LatLng(43.51, 16.44);
      const ljubljana = LatLng(46.05, 14.51);
      const murskaSobota = LatLng(46.66, 16.17);
      const vienna = LatLng(48.21, 16.37);
      expect(hr.contains(split), isTrue);
      expect(si.contains(split), isFalse);
      expect(si.contains(ljubljana), isTrue);
      // A box, so it only trims the edges: most of Slovenia is inside
      // Croatia's box, the north-east is not.
      expect(hr.contains(ljubljana), isTrue);
      expect(hr.contains(murskaSobota), isFalse);
      expect(hr.contains(vienna) || si.contains(vienna), isFalse);
      expect(MapLayer.openStreetMap.orthoCoverage, isNull);
    });

    test('every partner is a base layer', () {
      for (final base in MapLayer.baseLayers) {
        for (final layer in MapLayer.stackFor(base)) {
          expect(MapLayer.baseLayers, contains(layer));
        }
      }
    });
  });
}

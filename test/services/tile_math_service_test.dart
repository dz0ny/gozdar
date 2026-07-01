import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/tile_math_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('TileMathService', () {
    test('converts lat lon to slippy tile coordinates', () {
      final (x, y) = TileMathService.latLonToTile(46.0569, 14.5058, 10);

      expect(x, 553);
      expect(y, 364);
    });

    test('computes tile bounds with north above south', () {
      final bounds = TileMathService.tileBounds(553, 364, 10);

      expect(bounds.north, greaterThan(bounds.south));
      expect(bounds.east, greaterThan(bounds.west));
      expect(bounds.north, closeTo(46.0732, 0.01));
      expect(bounds.west, closeTo(14.4141, 0.01));
    });

    test('detects polygon containment', () {
      final polygon = [
        const LatLng(46.1, 14.4),
        const LatLng(46.1, 14.6),
        const LatLng(45.9, 14.6),
        const LatLng(45.9, 14.4),
      ];

      expect(
        TileMathService.polygonContains(polygon, const LatLng(46.0, 14.5)),
        isTrue,
      );
      expect(
        TileMathService.polygonContains(polygon, const LatLng(46.2, 14.5)),
        isFalse,
      );
    });

    test('returns tiles for polygon and estimate is not lower than exact', () {
      final polygon = [
        const LatLng(46.1, 14.4),
        const LatLng(46.1, 14.6),
        const LatLng(45.9, 14.6),
        const LatLng(45.9, 14.4),
      ];

      final tiles = TileMathService.getTilesForPolygons([polygon], 10, 11);
      final estimate = TileMathService.estimateTileCount([polygon], 10, 11);

      expect(tiles, isNotEmpty);
      expect(estimate, greaterThanOrEqualTo(tiles.length));
      expect(tiles.toSet().length, tiles.length);
    });
  });
}

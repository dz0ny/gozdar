import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/widgets/location_tracker.dart';
import 'package:latlong2/latlong.dart';

final _square = [
  const LatLng(46, 14),
  const LatLng(46.01, 14),
  const LatLng(46.01, 14.01),
  const LatLng(46, 14.01),
];

void main() {
  group('Parcel polygon cache', () {
    test('reuses the decoded polygon while the JSON is unchanged', () {
      final parcel = Parcel(name: 'A', polygon: _square);
      expect(identical(parcel.polygon, parcel.polygon), isTrue);
      expect(parcel.polygon, _square);
    });

    test('the cached lists are read-only', () {
      final parcel = Parcel(name: 'A', polygon: _square);
      expect(
        () => parcel.polygon.add(const LatLng(0, 0)),
        throwsUnsupportedError,
      );
      expect(() => parcel.pointNames[0] = 'x', throwsUnsupportedError);
    });

    test('assigning polygon refreshes polygon and area', () {
      final parcel = Parcel(name: 'A', polygon: _square);
      final area = parcel.areaM2;
      expect(area, greaterThan(0));

      parcel.polygon = _square.take(3).toList();

      expect(parcel.polygon, hasLength(3));
      expect(parcel.areaM2, closeTo(area / 2, area * 0.01));
    });

    test('assigning polygonJson directly refreshes the cache', () {
      final parcel = Parcel(name: 'A', polygon: _square);
      expect(parcel.containsPoint(const LatLng(46.005, 14.005)), isTrue);

      parcel.polygonJson = '[]';

      expect(parcel.polygon, isEmpty);
      expect(parcel.areaM2, 0);
      expect(parcel.containsPoint(const LatLng(46.005, 14.005)), isFalse);
    });

    test('withPointName and copyWith give fresh, independent data', () {
      final parcel = Parcel(name: 'A', polygon: _square);
      expect(parcel.pointNames, [null, null, null, null]);

      final named = parcel.withPointName(1, 'Hrast');
      expect(named.pointNames, [null, 'Hrast', null, null]);
      expect(parcel.pointNames, [null, null, null, null]);

      final moved = named.copyWith(polygon: _square.take(3).toList());
      expect(moved.polygon, hasLength(3));
      expect(named.polygon, hasLength(4));
    });
  });

  group('LocationTracker.headingMoved', () {
    test('ignores jitter below the step', () {
      expect(LocationTracker.headingMoved(10, 11.5), isFalse);
      expect(LocationTracker.headingMoved(10, 12), isTrue);
    });

    test('measures across north', () {
      expect(LocationTracker.headingMoved(359.5, 0.5), isFalse);
      expect(LocationTracker.headingMoved(359, 1), isTrue);
      expect(LocationTracker.headingMoved(1, 359), isTrue);
    });

    test('a heading appearing or going away counts', () {
      expect(LocationTracker.headingMoved(null, 10), isTrue);
      expect(LocationTracker.headingMoved(10, null), isTrue);
      expect(LocationTracker.headingMoved(null, null), isFalse);
    });
  });
}

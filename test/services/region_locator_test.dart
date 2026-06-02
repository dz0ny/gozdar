import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:gozdar/services/region_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('resolves known points to statistical regions', () async {
    await RegionLocator.instance.ensureLoaded();
    expect(RegionLocator.instance.isLoaded, true);
    // Ljubljana
    expect(RegionLocator.instance.regionForPoint(LatLng(46.056, 14.506))?.name,
        'Osrednjeslovenska');
    // Koper (coast)
    expect(RegionLocator.instance.regionForPoint(LatLng(45.548, 13.730))?.name,
        'Obalno-kraška');
    // Maribor
    expect(RegionLocator.instance.regionForPoint(LatLng(46.554, 15.646))?.name,
        'Podravska');
    // Out of country -> null
    expect(RegionLocator.instance.regionForPoint(LatLng(48.0, 16.0)), isNull);
  });
}

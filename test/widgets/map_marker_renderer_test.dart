import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/widgets/location_pointer.dart';
import 'package:gozdar/widgets/map_marker_renderer.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('user location pointer uses zoom-scaled marker size', () {
    final renderer = MapMarkerRenderer(
      currentZoom: 15,
      locations: const [],
      parcels: const [],
      geolocatedLogs: const [],
      userPosition: const LatLng(46, 14),
      userHeading: 0,
      primaryColor: Colors.green,
    );

    final marker = renderer.buildUserLocationMarker();
    final pointer = marker!.child as LocationPointer;

    expect(pointer.size, marker.width);
    expect(pointer.size, lessThan(40));
  });
}

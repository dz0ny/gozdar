import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/models/received_share.dart';
import 'package:gozdar/models/secnja_share.dart';
import 'package:gozdar/widgets/location_pointer.dart';
import 'package:gozdar/widgets/map_marker_renderer.dart';
import 'package:latlong2/latlong.dart';

void main() {
  receivedShareTests();

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

ReceivedShare _share({bool visible = true}) => ReceivedShare(
      shareId: 'abc',
      payloadJson: jsonEncode(SecnjaSharePayload(
        parcelNumber: '1234/5',
        points: [
          SecnjaPoint(name: 'Smreka 1', lat: 46.001, lng: 14.001),
          SecnjaPoint(name: 'Drevo 2', lat: 46.002, lng: 14.002),
        ],
        createdAt: DateTime.utc(2026, 11, 2),
      ).toJson()),
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 5)),
      visible: visible,
    );

MapMarkerRenderer _renderer(List<ReceivedShare> shares) => MapMarkerRenderer(
      currentZoom: 16,
      locations: const [],
      parcels: const [],
      geolocatedLogs: const [],
      userPosition: null,
      userHeading: null,
      primaryColor: Colors.green,
      receivedShares: shares,
    );

void receivedShareTests() {
  test('hidden share draws no markers', () {
    expect(_renderer([_share(visible: false)]).buildReceivedShareMarkers(), isEmpty);
  });

  testWidgets('visible share draws numbered blue markers in payload order', (tester) async {
    final markers = _renderer([_share()]).buildReceivedShareMarkers();
    expect(markers.map((m) => m.point), const [LatLng(46.001, 14.001), LatLng(46.002, 14.002)]);
    await tester.pumpWidget(MaterialApp(home: Row(children: [for (final m in markers) m.child])));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}

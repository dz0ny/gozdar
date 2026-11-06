import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/widgets/location_pointer.dart';
import 'package:gozdar/widgets/location_tracker.dart';
import 'package:gozdar/widgets/user_location_layer.dart';
import 'package:latlong2/latlong.dart';

/// Counts its own builds, standing in for the map tab around the layers.
class _CountingParent extends StatelessWidget {
  const _CountingParent({required this.builds, required this.children});

  final List<int> builds;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    builds[0]++;
    return MaterialApp(
      home: SizedBox(
        width: 400,
        height: 400,
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(46, 14),
            initialZoom: 15,
          ),
          children: children,
        ),
      ),
    );
  }
}

void main() {
  testWidgets('draws nothing until the first fix, then follows each fix '
      'without rebuilding its parent', (tester) async {
    final fix = ValueNotifier<UserFix?>(null);
    addTearDown(fix.dispose);
    final builds = [0];

    await tester.pumpWidget(
      _CountingParent(
        builds: builds,
        children: [
          UserLocationLayer(fix: fix, size: 24, color: Colors.green),
          NavigationLineLayer(fix: fix, target: const LatLng(46.001, 14.001)),
        ],
      ),
    );
    expect(find.byType(LocationPointer), findsNothing);
    expect(find.byType(PolylineLayer), findsNothing);

    fix.value = const UserFix(LatLng(46, 14), 90);
    await tester.pump();

    final pointer = tester.widget<LocationPointer>(
      find.byType(LocationPointer),
    );
    expect(pointer.heading, 90);
    expect(pointer.size, 24);
    expect(find.byType(PolylineLayer), findsOneWidget);

    fix.value = const UserFix(LatLng(46.0005, 14), 180);
    await tester.pump();

    expect(
      tester.widget<LocationPointer>(find.byType(LocationPointer)).heading,
      180,
    );
    final marker = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(marker.markers.single.point, const LatLng(46.0005, 14));
    expect(builds[0], 1);
  });
}

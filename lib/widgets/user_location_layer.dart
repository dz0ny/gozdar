import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'location_tracker.dart';
import 'map_marker_renderer.dart';

/// The user's position and heading on the map. Listens to [fix] itself, so a
/// GPS fix or compass turn redraws only this layer, not the map tab.
class UserLocationLayer extends StatelessWidget {
  const UserLocationLayer({
    super.key,
    required this.fix,
    required this.size,
    required this.color,
  });

  final ValueListenable<UserFix?> fix;

  /// Marker size, already scaled to the zoom.
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserFix?>(
      valueListenable: fix,
      builder: (context, fix, _) {
        if (fix == null) return const SizedBox.shrink();
        return MarkerLayer(
          markers: [
            MapMarkerRenderer.userLocationMarker(
              position: fix.position,
              heading: fix.heading,
              size: size,
              color: color,
            ),
          ],
        );
      },
    );
  }
}

/// Dotted line from the user to the navigation [target], redrawn on each
/// [fix] without rebuilding the map tab.
class NavigationLineLayer extends StatelessWidget {
  const NavigationLineLayer({
    super.key,
    required this.fix,
    required this.target,
  });

  final ValueListenable<UserFix?> fix;
  final LatLng target;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserFix?>(
      valueListenable: fix,
      builder: (context, fix, _) {
        if (fix == null) return const SizedBox.shrink();
        return PolylineLayer(
          polylines: [
            Polyline(
              points: [fix.position, target],
              color: Colors.orange.withValues(alpha: 0.6),
              strokeWidth: 3,
              pattern: const StrokePattern.dotted(),
            ),
          ],
        );
      },
    );
  }
}

import 'package:latlong2/latlong.dart';

/// Navigation target for map view
/// Contains the target location and name to display
class NavigationTarget {
  final LatLng location;
  final String name;

  const NavigationTarget({
    required this.location,
    required this.name,
  });
}

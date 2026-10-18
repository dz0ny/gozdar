import 'package:latlong2/latlong.dart';

/// Navigation target for map view
/// Contains the target location and name to display
class NavigationTarget {
  final LatLng location;
  final String name;

  /// Open the compass navigation right away instead of only marking the
  /// target on the map ("Navigiraj" vs "Poglej na karti").
  final bool startNavigation;

  const NavigationTarget({
    required this.location,
    required this.name,
    this.startNavigation = false,
  });
}

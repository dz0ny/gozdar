import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../services/location_settings.dart';

/// Where the user is and which way they face.
@immutable
class UserFix {
  const UserFix(this.position, this.heading);

  final LatLng position;
  final double? heading;

  @override
  bool operator ==(Object other) =>
      other is UserFix &&
      other.position == position &&
      other.heading == heading;

  @override
  int get hashCode => Object.hash(position, heading);
}

/// Manages user location tracking and compass functionality
class LocationTracker {
  static const bool _isScreenshotRun = bool.fromEnvironment(
    'GOZDAR_SCREENSHOTS',
  );
  Position? _userPosition;
  double? _userHeading;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // Callbacks for state updates
  final Function(Position? position, double? heading)? onLocationUpdate;

  // Getters
  Position? get userPosition => _userPosition;
  double? get userHeading => _userHeading;

  LocationTracker({this.onLocationUpdate});

  /// The latest fix, for widgets that redraw only the user's position, so a
  /// GPS fix or compass turn doesn't rebuild the whole map.
  final ValueNotifier<UserFix?> fix = ValueNotifier(null);

  void _report() {
    final position = _userPosition;
    if (position != null) {
      fix.value = UserFix(
        LatLng(position.latitude, position.longitude),
        _userHeading,
      );
    }
    onLocationUpdate?.call(_userPosition, _userHeading);
  }

  /// Smallest heading change, in degrees, worth redrawing the map for.
  static const double headingStepDeg = 2;

  /// Whether the heading went from [from] to [to] by at least
  /// [headingStepDeg], across north too (359° to 1° is 2°). A heading
  /// appearing or going away always counts.
  static bool headingMoved(double? from, double? to) {
    if (from == null || to == null) return from != to;
    final diff = (to - from).abs() % 360;
    return (diff > 180 ? 360 - diff : diff) >= headingStepDeg;
  }

  /// Initialize location tracking
  Future<void> initialize() async {
    if (_isScreenshotRun) return;

    // Check location permission first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint(
        'Location permission denied (permanently: ${permission == LocationPermission.deniedForever})',
      );
      return;
    }

    // Get initial position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: GozdarLocationSettings.currentPosition,
      );
      _userPosition = position;
      _report();
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }

    // Start location updates
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: GozdarLocationSettings.stream,
        ).listen(
          (Position position) {
            _userPosition = position;
            // Use GPS heading as fallback if compass is unavailable
            if (_userHeading == null && position.heading >= 0) {
              _userHeading = position.heading;
            }
            _report();
          },
          onError: (error) {
            debugPrint('Location stream error: $error');
          },
        );

    // Start compass updates
    _compassSubscription = FlutterCompass.events?.listen(
      (CompassEvent event) {
        // The compass reports many times a second and jitters by fractions
        // of a degree; each report rebuilds the whole map tab. Only report
        // turns big enough to see on the heading marker.
        if (!headingMoved(_userHeading, event.heading)) return;
        _userHeading = event.heading;
        _report();
      },
      onError: (error) {
        debugPrint('Compass error: $error');
      },
    );
  }

  /// Dispose of resources
  void dispose() {
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    fix.dispose();
  }
}

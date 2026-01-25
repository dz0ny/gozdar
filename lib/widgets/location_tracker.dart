import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// Manages user location tracking and compass functionality
class LocationTracker {
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

  /// Initialize location tracking
  Future<void> initialize() async {
    // Check location permission first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied (permanently: ${permission == LocationPermission.deniedForever})');
      return;
    }

    // Get initial position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _userPosition = position;
      onLocationUpdate?.call(_userPosition, _userHeading);
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }

    // Start location updates
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // Update every 5 meters
          ),
        ).listen(
          (Position position) {
            _userPosition = position;
            // Use GPS heading as fallback if compass is unavailable
            if (_userHeading == null && position.heading >= 0) {
              _userHeading = position.heading;
            }
            onLocationUpdate?.call(_userPosition, _userHeading);
          },
          onError: (error) {
            debugPrint('Location stream error: $error');
          },
        );

    // Start compass updates
    _compassSubscription = FlutterCompass.events?.listen(
      (CompassEvent event) {
        _userHeading = event.heading;
        onLocationUpdate?.call(_userPosition, _userHeading);
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
  }
}

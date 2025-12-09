import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'compass_painter.dart';

/// Compass-only navigation dialog (no map)
/// Shows compass with bearing/distance info to target location
class NavigationCompassDialog extends StatefulWidget {
  final LatLng targetLocation;
  final String targetName;

  const NavigationCompassDialog({
    super.key,
    required this.targetLocation,
    required this.targetName,
  });

  @override
  State<NavigationCompassDialog> createState() =>
      _NavigationCompassDialogState();
}

class _NavigationCompassDialogState extends State<NavigationCompassDialog> {
  double? _currentHeading;
  double? _compassAccuracy;
  Position? _currentPosition;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;
  bool _showDMS = false;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    // Subscribe to compass updates
    final compassStream = FlutterCompass.events;
    if (compassStream != null) {
      _compassSubscription = compassStream.listen((event) {
        if (mounted && event.heading != null) {
          setState(() {
            _currentHeading = event.heading;
            _compassAccuracy = event.accuracy;
          });
        }
      });
    }

    // Subscribe to position updates
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 1,
          ),
        ).listen(
          (position) {
            if (mounted) {
              setState(() {
                _currentPosition = position;
              });
            }
          },
          onError: (error) {
            debugPrint('Position stream error: $error');
          },
        );

    // Get initial position
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting current position: $e');
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  // Get current heading (prefer compass over GPS)
  double? get currentHeading {
    if (_currentHeading != null) return _currentHeading;
    if (_currentPosition?.heading != null && _currentPosition!.heading >= 0) {
      return _currentPosition!.heading;
    }
    return null;
  }

  double? _calculateBearing() {
    if (_currentPosition == null) return null;

    final dLon =
        (widget.targetLocation.longitude - _currentPosition!.longitude) *
        pi /
        180;
    final lat1Rad = _currentPosition!.latitude * pi / 180;
    final lat2Rad = widget.targetLocation.latitude * pi / 180;

    final y = sin(dLon) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  double? _calculateDistance() {
    if (_currentPosition == null) return null;

    const R = 6371000; // Earth's radius in meters
    final dLat =
        (widget.targetLocation.latitude - _currentPosition!.latitude) *
        pi /
        180;
    final dLon =
        (widget.targetLocation.longitude - _currentPosition!.longitude) *
        pi /
        180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_currentPosition!.latitude * pi / 180) *
            cos(widget.targetLocation.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  String _bearingToCardinal(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  String _formatDMS(double degrees, bool isLatitude) {
    final direction = isLatitude
        ? (degrees >= 0 ? 'N' : 'S')
        : (degrees >= 0 ? 'E' : 'W');

    final absolute = degrees.abs();
    final deg = absolute.floor();
    final minDecimal = (absolute - deg) * 60;
    final min = minDecimal.floor();
    final sec = (minDecimal - min) * 60;

    return '$deg°${min.toString().padLeft(2, '0')}\'${sec.toStringAsFixed(1).padLeft(4, '0')}"$direction';
  }

  // Check if compass accuracy is low
  String? get _accuracyWarning {
    if (_compassAccuracy != null && _compassAccuracy! > 30) {
      return 'Nizka natancnost kompasa (±${_compassAccuracy!.round()}°). Kalibrirajte napravo.';
    } else if (_compassAccuracy != null && _compassAccuracy! > 15) {
      return 'Zmerna natancnost kompasa (±${_compassAccuracy!.round()}°)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final heading = currentHeading;
    final bearing = _calculateBearing();
    final distance = _calculateDistance();
    final accuracyWarning = _accuracyWarning;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(context),

          // Accuracy warning
          if (accuracyWarning != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _compassAccuracy! > 30
                    ? Colors.red.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _compassAccuracy! > 30
                        ? Icons.error_outline
                        : Icons.warning_amber_outlined,
                    color: _compassAccuracy! > 30
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      accuracyWarning,
                      style: TextStyle(
                        color: _compassAccuracy! > 30
                            ? Colors.red.shade700
                            : Colors.orange.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Compass + Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Info row: Distance, Bearing, Direction
                _buildInfoRow(bearing, distance),
                const SizedBox(height: 24),

                // Compass
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: CompassPainter(
                      heading: heading ?? 0,
                      hasHeading: heading != null,
                      currentPosition: _currentPosition,
                      targetLocation: widget.targetLocation,
                      theme: Theme.of(context),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Target coordinates
                _buildCoordinatesCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Kompas',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.targetName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildInfoRow(double? bearing, double? distance) {
    final gpsAccuracy = _currentPosition?.accuracy;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildInfoCard(
          'Razdalja',
          distance != null ? _formatDistance(distance) : '--',
          Icons.straighten,
        ),
        _buildInfoCard(
          'Azimut',
          bearing != null ? '${bearing.round()}°' : '--',
          Icons.navigation,
        ),
        _buildInfoCard(
          'Smer',
          bearing != null ? _bearingToCardinal(bearing) : '--',
          Icons.explore,
        ),
        _buildInfoCard(
          'GPS',
          gpsAccuracy != null ? '±${gpsAccuracy.round()}m' : '--',
          Icons.gps_fixed,
          color: gpsAccuracy != null
              ? (gpsAccuracy <= 5
                    ? Colors.green
                    : gpsAccuracy <= 15
                    ? Colors.orange
                    : Colors.red)
              : null,
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final displayColor = color ?? Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Icon(icon, size: 24, color: displayColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: displayColor,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildCoordinatesCard() {
    final String displayText;
    if (_showDMS) {
      displayText =
          '${_formatDMS(widget.targetLocation.latitude, true)} ${_formatDMS(widget.targetLocation.longitude, false)}';
    } else {
      displayText =
          '${widget.targetLocation.latitude.toStringAsFixed(5)}, ${widget.targetLocation.longitude.toStringAsFixed(5)}';
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showDMS = !_showDMS;
        });
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                displayText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.swap_horiz, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

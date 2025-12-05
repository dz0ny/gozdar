import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Large compass painter that shows direction to a target location
class CompassPainter extends CustomPainter {
  final double heading;
  final bool hasHeading;
  final Position? currentPosition;
  final LatLng targetLocation;
  final Color targetColor;

  CompassPainter({
    required this.heading,
    required this.hasHeading,
    required this.currentPosition,
    required this.targetLocation,
    this.targetColor = Colors.red,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer circle
    final circlePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw degree markers
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 360; i += 10) {
      final angle = i * pi / 180 - pi / 2 + heading * pi / 180;
      final isCardinal = i % 90 == 0;
      final isMajor = i % 30 == 0;

      final startRadius =
          isCardinal ? radius - 25 : (isMajor ? radius - 15 : radius - 10);
      final start = Offset(
        center.dx + startRadius * cos(angle),
        center.dy + startRadius * sin(angle),
      );
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      final markerPaint = Paint()
        ..color = isCardinal ? Colors.red : Colors.grey
        ..strokeWidth = isCardinal ? 3 : (isMajor ? 2 : 1);

      canvas.drawLine(start, end, markerPaint);
    }

    // Draw cardinal directions
    final directions = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2 - pi / 2 + heading * pi / 180;
      final x = center.dx + (radius - 35) * cos(angle);
      final y = center.dy + (radius - 35) * sin(angle);

      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: i == 0 ? Colors.red : Colors.grey.shade700,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // Draw target indicator if we have current position
    if (currentPosition != null) {
      final bearing = _calculateBearing(
        currentPosition!.latitude,
        currentPosition!.longitude,
        targetLocation.latitude,
        targetLocation.longitude,
      );
      final distance = _calculateDistance(
        currentPosition!.latitude,
        currentPosition!.longitude,
        targetLocation.latitude,
        targetLocation.longitude,
      );

      // Adjust bearing relative to current heading
      final relativeBearing = (bearing - heading + 360) % 360;
      final angle = relativeBearing * pi / 180 - pi / 2;

      // Position target at 70% of radius
      final targetRadius = radius * 0.7;
      final dotX = center.dx + targetRadius * cos(angle);
      final dotY = center.dy + targetRadius * sin(angle);

      // Draw line from center to target
      final linePaint = Paint()
        ..color = targetColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(center, Offset(dotX, dotY), linePaint);

      // Draw target dot
      final dotPaint = Paint()
        ..color = targetColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), 10, dotPaint);

      // Draw target border
      final borderPaint = Paint()
        ..color = targetColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(Offset(dotX, dotY), 10, borderPaint);

      // Draw distance label
      final distanceText = _formatDistance(distance);
      final labelOffset = 20.0;
      final labelX = center.dx + (targetRadius + labelOffset) * cos(angle);
      final labelY = center.dy + (targetRadius + labelOffset) * sin(angle);

      textPainter.text = TextSpan(
        text: distanceText,
        style: TextStyle(
          color: targetColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      // Draw background for readability
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(labelX, labelY),
          width: textPainter.width + 8,
          height: textPainter.height + 4,
        ),
        const Radius.circular(4),
      );
      final bgPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(bgRect, bgPaint);

      textPainter.paint(
        canvas,
        Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2),
      );
    }

    // Draw center heading indicator (fixed pointing up)
    final indicatorPaint = Paint()
      ..color = hasHeading ? Colors.red : Colors.grey
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(center.dx, center.dy - 35)
      ..lineTo(center.dx - 8, center.dy + 5)
      ..lineTo(center.dx + 8, center.dy + 5)
      ..close();

    canvas.drawPath(path, indicatorPaint);

    // Draw center dot
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerPaint);
  }

  double _calculateBearing(
      double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;

    final y = sin(dLon) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Earth's radius in meters
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

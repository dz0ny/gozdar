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
  final ThemeData theme;

  CompassPainter({
    required this.heading,
    required this.hasHeading,
    required this.currentPosition,
    required this.targetLocation,
    this.targetColor = Colors.red,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final colorScheme = theme.colorScheme;

    // Draw outer circle with theme-based gradient
    final circlePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          colorScheme.outline.withValues(alpha: 0.7),
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          colorScheme.surface.withValues(alpha: 0.2),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw inner background circle with theme colors
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [colorScheme.surface, colorScheme.surfaceContainerHighest],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.95));
    canvas.drawCircle(center, radius * 0.95, bgPaint);

    // Draw degree markers with enhanced styling
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 360; i += 10) {
      final angle = i * pi / 180 - pi / 2 + heading * pi / 180;
      final isCardinal = i % 90 == 0;
      final isMajor = i % 30 == 0;

      final startRadius = isCardinal
          ? radius - 30
          : (isMajor ? radius - 18 : radius - 12);
      final start = Offset(
        center.dx + startRadius * cos(angle),
        center.dy + startRadius * sin(angle),
      );
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      final markerPaint = Paint()
        ..color = isCardinal
            ? colorScheme.primary.withValues(alpha: 0.8)
            : isMajor
            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        ..strokeWidth = isCardinal ? 3 : (isMajor ? 2 : 1)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(start, end, markerPaint);
    }

    // Draw cardinal directions with theme colors
    final directions = ['N', 'E', 'S', 'W'];
    final directionColors = [
      colorScheme.primary, // North - primary (warm wood tan)
      colorScheme.onSurfaceVariant, // East
      colorScheme.onSurfaceVariant, // South
      colorScheme.onSurfaceVariant, // West
    ];

    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2 - pi / 2 + heading * pi / 180;
      final x = center.dx + (radius - 40) * cos(angle);
      final y = center.dy + (radius - 40) * sin(angle);

      // Draw background circle for direction letters with theme colors
      final bgCirclePaint = Paint()
        ..color = colorScheme.surface.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 14, bgCirclePaint);

      // Draw border for direction letters with theme colors
      final borderPaint = Paint()
        ..color = directionColors[i].withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(x, y), 14, borderPaint);

      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: directionColors[i],
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: colorScheme.surface.withValues(alpha: 0.8),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
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

      // Draw line from center to target with theme-based gradient
      final linePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment.centerRight,
          colors: [
            targetColor.withValues(alpha: 0.1),
            targetColor.withValues(alpha: 0.5),
          ],
        ).createShader(Rect.fromPoints(center, Offset(dotX, dotY)))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, Offset(dotX, dotY), linePaint);

      // Draw target dot with shadow effect using theme colors
      final shadowPaint = Paint()
        ..color = colorScheme.shadow.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX + 1, dotY + 1), 12, shadowPaint);

      // Draw target dot with gradient
      final dotPaint = Paint()
        ..shader = RadialGradient(
          colors: [targetColor, targetColor.withValues(alpha: 0.8)],
        ).createShader(Rect.fromCircle(center: Offset(dotX, dotY), radius: 10));
      canvas.drawCircle(Offset(dotX, dotY), 10, dotPaint);

      // Draw target border with theme colors
      final borderPaint = Paint()
        ..color = colorScheme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(dotX, dotY), 10, borderPaint);

      final glowPaint = Paint()
        ..color = targetColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(dotX, dotY), 10, glowPaint);

      // Draw distance label with enhanced styling
      final distanceText = _formatDistance(distance);
      final labelOffset = 25.0;
      final labelX = center.dx + (targetRadius + labelOffset) * cos(angle);
      final labelY = center.dy + (targetRadius + labelOffset) * sin(angle);

      textPainter.text = TextSpan(
        text: distanceText,
        style: TextStyle(
          color: targetColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      );
      textPainter.layout();

      // Draw background for readability with theme colors
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(labelX, labelY),
          width: textPainter.width + 12,
          height: textPainter.height + 6,
        ),
        const Radius.circular(8),
      );

      // Shadow with theme colors
      final shadowRectPaint = Paint()
        ..color = colorScheme.shadow.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(bgRect.shift(const Offset(1, 1)), shadowRectPaint);

      // Background with theme colors
      final bgPaint = Paint()
        ..color = colorScheme.surface.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(bgRect, bgPaint);

      // Border with theme colors
      final borderRectPaint = Paint()
        ..color = targetColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(bgRect, borderRectPaint);

      textPainter.paint(
        canvas,
        Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2),
      );
    }

    // Draw enhanced center heading indicator with theme colors
    final indicatorColor = hasHeading
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    // Create more elegant needle shape
    final needlePath = ui.Path()
      ..moveTo(center.dx, center.dy - 40) // Top point - more elongated
      ..lineTo(center.dx - 6, center.dy - 8) // Upper left
      ..lineTo(center.dx - 4, center.dy + 8) // Lower left
      ..lineTo(center.dx, center.dy + 2) // Bottom center
      ..lineTo(center.dx + 4, center.dy + 8) // Lower right
      ..lineTo(center.dx + 6, center.dy - 8) // Upper right
      ..close();

    // Shadow for indicator with theme colors
    final shadowPaint = Paint()
      ..color = colorScheme.shadow.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawPath(needlePath.shift(const Offset(1.5, 1.5)), shadowPaint);

    // Main indicator with enhanced gradient using theme colors
    final indicatorPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              indicatorColor,
              indicatorColor.withValues(alpha: 0.9),
              indicatorColor.withValues(alpha: 0.7),
            ],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(
            Rect.fromPoints(
              Offset(center.dx - 6, center.dy - 40),
              Offset(center.dx + 6, center.dy + 8),
            ),
          );

    canvas.drawPath(needlePath, indicatorPaint);

    // Indicator border with theme colors
    final borderPaint = Paint()
      ..color = colorScheme.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(needlePath, borderPaint);

    // Add inner highlight for depth
    final highlightPath = ui.Path()
      ..moveTo(center.dx, center.dy - 35)
      ..lineTo(center.dx - 3, center.dy - 6)
      ..lineTo(center.dx, center.dy + 2)
      ..lineTo(center.dx + 3, center.dy - 6)
      ..close();

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(highlightPath, highlightPaint);

    // Draw center dot with theme colors
    // Shadow with theme colors
    final centerShadowPaint = Paint()
      ..color = colorScheme.shadow.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx + 0.5, center.dy + 0.5),
      5,
      centerShadowPaint,
    );

    // Main dot with gradient using theme colors
    final centerPaint = Paint()
      ..shader = RadialGradient(
        colors: [colorScheme.surface, colorScheme.surfaceContainerHighest],
      ).createShader(Rect.fromCircle(center: center, radius: 4.5));
    canvas.drawCircle(center, 4.5, centerPaint);

    // Center dot border with theme colors
    final centerBorderPaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 4.5, centerBorderPaint);
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;

    final y = sin(dLon) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // Earth's radius in meters
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
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

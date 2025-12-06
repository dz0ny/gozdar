import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// A widget that displays a small silhouette/preview of a parcel polygon
class ParcelSilhouette extends StatelessWidget {
  final List<LatLng> polygon;
  final double size;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;

  const ParcelSilhouette({
    super.key,
    required this.polygon,
    this.size = 48,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    if (polygon.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.landscape,
          size: size * 0.6,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final fill = fillColor ?? colorScheme.primaryContainer;
    final stroke = strokeColor ?? colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PolygonPainter(
          polygon: polygon,
          fillColor: fill,
          strokeColor: stroke,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _PolygonPainter extends CustomPainter {
  final List<LatLng> polygon;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  _PolygonPainter({
    required this.polygon,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.isEmpty) return;

    // Find bounds
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final point in polygon) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;

    // Add padding
    final padding = size.width * 0.1;
    final drawWidth = size.width - padding * 2;
    final drawHeight = size.height - padding * 2;

    // Scale to fit
    final scale = latRange > 0 && lngRange > 0
        ? (drawWidth / lngRange).clamp(0.0, drawHeight / latRange)
        : 1.0;

    // Center offset
    final scaledWidth = lngRange * scale;
    final scaledHeight = latRange * scale;
    final offsetX = padding + (drawWidth - scaledWidth) / 2;
    final offsetY = padding + (drawHeight - scaledHeight) / 2;

    // Convert to screen coordinates
    final path = ui.Path();
    for (int i = 0; i < polygon.length; i++) {
      final point = polygon[i];
      // Flip Y because screen coordinates are inverted
      final x = offsetX + (point.longitude - minLng) * scale;
      final y = offsetY + (maxLat - point.latitude) * scale;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Draw fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw stroke
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Draw vertex dots
    final dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    final dotRadius = strokeWidth * 1.5;

    for (final point in polygon) {
      final x = offsetX + (point.longitude - minLng) * scale;
      final y = offsetY + (maxLat - point.latitude) * scale;
      canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) {
    return oldDelegate.polygon != polygon ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeColor != strokeColor;
  }
}

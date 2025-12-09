import 'dart:math';
import 'package:flutter/material.dart';

/// Small compass indicator widget (56x56)
/// Shows compass rose with cardinal directions, red needle, and heading text
class CompassWidget extends StatelessWidget {
  final double heading;
  final bool hasHeading;

  const CompassWidget({
    super.key,
    required this.heading,
    required this.hasHeading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.surfaceContainerHighest, colorScheme.surface],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Compass rose background - rotates to show true north at top
          Transform.rotate(
            angle: heading * pi / 180,
            child: CustomPaint(
              size: const Size(40, 40),
              painter: _CompassRosePainter(theme: theme),
            ),
          ),
          // Enhanced needle pointing up (since map rotates)
          Transform.rotate(
            angle: -pi / 2, // Point north
            child: CustomPaint(
              size: const Size(24, 32),
              painter: _CompassNeedlePainter(
                color: hasHeading
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                hasShadow: hasHeading,
              ),
            ),
          ),
          // Heading text with theme colors
          Positioned(
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                hasHeading ? '${heading.round()}°' : '--',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassRosePainter extends CustomPainter {
  final ThemeData theme;

  _CompassRosePainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final colorScheme = theme.colorScheme;

    // Draw outer circle with theme-based gradient
    final circlePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          colorScheme.outline.withValues(alpha: 0.6),
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          colorScheme.surface.withValues(alpha: 0.2),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, circlePaint);

    // Draw inner circle with theme colors
    final innerCirclePaint = Paint()
      ..color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.85, innerCirclePaint);

    // Draw cardinal direction markers with theme colors
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final directions = ['N', 'E', 'S', 'W'];
    final directionColors = [
      colorScheme.primary, // North - primary (warm wood tan)
      colorScheme.onSurfaceVariant, // East
      colorScheme.onSurfaceVariant, // South
      colorScheme.onSurfaceVariant, // West
    ];

    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2 - pi / 2; // Start from North (top)
      final x = center.dx + radius * 0.75 * cos(angle);
      final y = center.dy + radius * 0.75 * sin(angle);

      // Draw direction line with theme colors
      final linePaint = Paint()
        ..color = directionColors[i].withValues(alpha: 0.7)
        ..strokeWidth = i == 0
            ? 2.5
            : 1.5 // Thicker line for North
        ..strokeCap = StrokeCap.round;

      final lineStart = Offset(
        center.dx + radius * 0.45 * cos(angle),
        center.dy + radius * 0.45 * sin(angle),
      );
      final lineEnd = Offset(
        center.dx + radius * 0.82 * cos(angle),
        center.dy + radius * 0.82 * sin(angle),
      );

      canvas.drawLine(lineStart, lineEnd, linePaint);

      // Draw direction text with theme colors
      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: directionColors[i],
          fontSize: 12,
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

    // Draw intermediate direction markers (NE, SE, SW, NW) with theme colors
    for (int i = 0; i < 4; i++) {
      final angle = (i * pi / 2) + (pi / 4) - pi / 2; // 45-degree offsets

      // Draw small tick mark with theme colors
      final tickPaint = Paint()
        ..color = colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;

      final tickStart = Offset(
        center.dx + radius * 0.75 * cos(angle),
        center.dy + radius * 0.75 * sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * 0.82 * cos(angle),
        center.dy + radius * 0.82 * sin(angle),
      );

      canvas.drawLine(tickStart, tickEnd, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompassNeedlePainter extends CustomPainter {
  final Color color;
  final bool hasShadow;

  _CompassNeedlePainter({required this.color, required this.hasShadow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Create needle path - more elegant diamond/arrow shape
    final needlePath = Path()
      ..moveTo(center.dx, center.dy - size.height / 2 + 2) // Top point
      ..lineTo(center.dx - 4, center.dy - 2) // Left mid point
      ..lineTo(center.dx - 2, center.dy + size.height / 2 - 2) // Left bottom
      ..lineTo(center.dx, center.dy + 2) // Bottom center
      ..lineTo(center.dx + 2, center.dy + size.height / 2 - 2) // Right bottom
      ..lineTo(center.dx + 4, center.dy - 2) // Right mid point
      ..close();

    if (hasShadow) {
      // Draw shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawPath(needlePath.shift(const Offset(1, 1)), shadowPaint);
    }

    // Draw main needle with gradient
    final needlePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0.8)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(needlePath, needlePaint);

    // Draw needle border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(needlePath, borderPaint);

    // Add inner highlight for more depth
    final highlightPath = Path()
      ..moveTo(center.dx, center.dy - size.height / 2 + 4)
      ..lineTo(center.dx - 2, center.dy - 2)
      ..lineTo(center.dx, center.dy + 2)
      ..lineTo(center.dx + 2, center.dy - 2)
      ..close();

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

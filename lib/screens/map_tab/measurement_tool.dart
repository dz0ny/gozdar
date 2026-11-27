part of '../map_tab.dart';

enum _MeasurementTool { distance, area }

enum _DistanceUnit { meters, kilometers }

enum _AreaUnit { squareMeters, hectares }

class _MeasurementState {
  final _MeasurementTool? tool;
  final List<LatLng> points;
  final bool isFinished;

  const _MeasurementState({
    this.tool,
    this.points = const [],
    this.isFinished = false,
  });

  bool get isActive => tool != null;

  bool get hasEnoughPoints {
    if (tool == _MeasurementTool.distance) {
      return points.length >= 2;
    }
    if (tool == _MeasurementTool.area) {
      return points.length >= 3;
    }
    return false;
  }

  _MeasurementState copyWith({
    _MeasurementTool? tool,
    List<LatLng>? points,
    bool? isFinished,
    bool clearTool = false,
  }) {
    return _MeasurementState(
      tool: clearTool ? null : (tool ?? this.tool),
      points: points ?? this.points,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

/// Fixed aiming reticle drawn at the centre of the map while measuring.
/// A circle + cross with a white outline (visible over any imagery) and a
/// coloured core, plus a tiny centre dot marking the exact target point.
class _MeasurementCrosshair extends StatelessWidget {
  const _MeasurementCrosshair({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(44, 44),
      painter: _MeasurementCrosshairPainter(color: color),
    );
  }
}

class _MeasurementCrosshairPainter extends CustomPainter {
  _MeasurementCrosshairPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 14.0;
    const arm = 9.0;

    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final core = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Cross arms (drawn with a gap over the centre so the ring/dot read clearly).
    final segments = <List<Offset>>[
      [
        Offset(center.dx, center.dy - radius - arm),
        Offset(center.dx, center.dy - radius),
      ],
      [
        Offset(center.dx, center.dy + radius),
        Offset(center.dx, center.dy + radius + arm),
      ],
      [
        Offset(center.dx - radius - arm, center.dy),
        Offset(center.dx - radius, center.dy),
      ],
      [
        Offset(center.dx + radius, center.dy),
        Offset(center.dx + radius + arm, center.dy),
      ],
    ];
    for (final s in segments) {
      canvas.drawLine(s[0], s[1], outline);
    }
    // Ring outline then coloured ring.
    canvas.drawCircle(center, radius, outline);
    for (final s in segments) {
      canvas.drawLine(s[0], s[1], core);
    }
    canvas.drawCircle(center, radius, core);

    // Exact-point centre dot: white halo + coloured fill.
    canvas.drawCircle(center, 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(center, 2.0, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MeasurementCrosshairPainter oldDelegate) =>
      oldDelegate.color != color;
}

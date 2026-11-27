part of '../map_tab.dart';

/// Distance and area measurement.
extension _Measurement on MapTabState {
  void _startMeasurement(_MeasurementTool tool, {LatLng? backTo}) {
    _measureBackTo = backTo;
    _setState(() {
      _measurement = _MeasurementState(tool: tool);
    });
  }

  /// Back from measuring: stop and, when it started from the long-press
  /// menu, open that menu again for the same point.
  void _backFromMeasurement() {
    final backTo = _measureBackTo;
    _measureBackTo = null;
    _closeMeasurement();
    if (backTo != null) _showLongPressMenu(backTo);
  }

  void _addMeasurementPoint(LatLng point) {
    if (!_measurement.isActive || _measurement.isFinished) return;

    _setState(() {
      _measurement = _measurement.copyWith(
        points: [..._measurement.points, point],
      );
    });
  }

  /// Append the current map-centre (where the crosshair is aimed) as the next
  /// measurement point.
  void _addMeasurementPointAtCrosshair() {
    _addMeasurementPoint(_mapController.camera.center);
  }

  void _closeMeasurement() {
    _setState(() {
      _measurement = const _MeasurementState();
    });
  }

  /// Remove the most recently added measurement point.
  void _undoMeasurementPoint() {
    if (_measurement.points.isEmpty) return;
    _setState(() {
      _measurement = _measurement.copyWith(
        points: _measurement.points.sublist(0, _measurement.points.length - 1),
        // Re-open the measurement if it had been finished.
        isFinished: false,
      );
    });
  }

  /// Lock the measurement so further taps no longer add points.
  void _finishMeasurement() {
    if (!_measurement.hasEnoughPoints) return;
    _setState(() {
      _measurement = _measurement.copyWith(isFinished: true);
    });
  }

  double _measurementDistanceMeters(List<LatLng> points) {
    if (points.length < 2) return 0;

    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }

    return total;
  }

  double _measurementAreaM2(List<LatLng> points) {
    if (points.length < 3) return 0;

    final centerLat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;

    final metersPerDegreeLat =
        111132.92 -
        559.82 * math.cos(2 * centerLat * math.pi / 180) +
        1.175 * math.cos(4 * centerLat * math.pi / 180);
    final metersPerDegreeLon =
        111412.84 * math.cos(centerLat * math.pi / 180) -
        93.5 * math.cos(3 * centerLat * math.pi / 180);

    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      final x1 = points[i].longitude * metersPerDegreeLon;
      final y1 = points[i].latitude * metersPerDegreeLat;
      final x2 = points[j].longitude * metersPerDegreeLon;
      final y2 = points[j].latitude * metersPerDegreeLat;

      area += x1 * y2 - x2 * y1;
    }

    return area.abs() / 2;
  }

  String _measurementValueLabel() {
    if (!_measurement.isActive) {
      return L10n.current.mapTabNoActiveMeasurement;
    }

    if (_measurement.tool == _MeasurementTool.distance) {
      final meters = _measurementDistanceMeters(_measurement.points);
      if (_distanceUnit == _DistanceUnit.kilometers) {
        return '${Fmt.num(meters / 1000, 2)} km';
      }
      return '${Fmt.num(meters, 0)} m';
    }

    final area = _measurementAreaM2(_measurement.points);
    if (_areaUnit == _AreaUnit.hectares) {
      return '${Fmt.num(area / 10000, 2)} ha';
    }
    return '${Fmt.num(area, 0)} m²';
  }

  /// Compact segmented control to switch measurement display units.
  Widget _measurementUnitSelector() {
    final style = SegmentedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      textStyle: Theme.of(context).textTheme.labelMedium,
    );
    if (_measurement.tool == _MeasurementTool.distance) {
      return SegmentedButton<_DistanceUnit>(
        style: style,
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _DistanceUnit.meters, label: Text('m')),
          ButtonSegment(value: _DistanceUnit.kilometers, label: Text('km')),
        ],
        selected: {_distanceUnit},
        onSelectionChanged: (s) => _setState(() => _distanceUnit = s.first),
      );
    }
    return SegmentedButton<_AreaUnit>(
      style: style,
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: _AreaUnit.squareMeters, label: Text('m²')),
        ButtonSegment(value: _AreaUnit.hectares, label: Text('ha')),
      ],
      selected: {_areaUnit},
      onSelectionChanged: (s) => _setState(() => _areaUnit = s.first),
    );
  }

  String _measurementHintLabel() {
    if (!_measurement.isActive) {
      return L10n.current.mapTabHintStart;
    }
    if (_measurement.isFinished) {
      return L10n.current.mapTabHintFinished;
    }
    if (_measurement.tool == _MeasurementTool.distance) {
      if (_measurement.points.length < 2) {
        return L10n.current.mapTabHintMoveMap;
      }
      return L10n.current.mapTabHintNextPointDistance;
    }
    if (_measurement.points.length < 3) {
      return L10n.current.mapTabHintMinPointsArea;
    }
    return L10n.current.mapTabHintNextPointPolygon;
  }

  List<Marker> _measurementMarkers() {
    return _measurement.points.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;

      return Marker(
        point: point,
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: _measurement.tool == _MeasurementTool.area
                ? Colors.deepPurple
                : Colors.teal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Fixed crosshair drawn at the centre of the map viewport while measuring.
  /// It is a screen-space overlay (not a map marker): the user pans/zooms the
  /// map to aim it, then taps "Dodaj točko" to drop the point under it. Styled
  /// with a white outline so it stays visible over both light and dark imagery.
  Widget _buildMeasurementCrosshair(BuildContext context) {
    final color = _measurement.tool == _MeasurementTool.area
        ? Colors.deepPurple
        : Colors.teal;
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(child: _MeasurementCrosshair(color: color)),
      ),
    );
  }

  Widget _buildMeasurementPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isArea = _measurement.tool == _MeasurementTool.area;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        elevation: 8,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        color: cs.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              SheetHeader(
                // Same icons and tints as the Merjenje tiles.
                icon: isArea ? Icons.square_foot : Icons.route,
                color: isArea ? Colors.deepPurple.shade200 : Colors.teal,
                title: isArea
                    ? L10n.current.mapTabMeasureArea
                    : L10n.current.mapTabMeasureDistance,
                subtitle: _measurementHintLabel(),
                onBack: _backFromMeasurement,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _measurementValueLabel(),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    _measurementUnitSelector(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SheetTileRow([
                SheetTile(
                  icon: Icons.undo,
                  label: L10n.current.mapTabUndo,
                  color: cs.onSurfaceVariant,
                  onTap: _measurement.points.isEmpty
                      ? null
                      : _undoMeasurementPoint,
                ),
                // Main action: add the point under the crosshair.
                SheetTile(
                  icon: Icons.add_location_alt,
                  label: L10n.current.mapTabAddPoint,
                  color: cs.primary,
                  onTap: _measurement.isFinished
                      ? null
                      : _addMeasurementPointAtCrosshair,
                ),
                SheetTile(
                  icon: Icons.check,
                  label: L10n.current.mapTabFinish,
                  color: Colors.green.shade300,
                  onTap:
                      (_measurement.hasEnoughPoints && !_measurement.isFinished)
                      ? _finishMeasurement
                      : null,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// Build tile layer for a specific layer
  /// All layers are cached for up to 1 year
}

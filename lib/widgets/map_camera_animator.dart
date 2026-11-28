import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/motion.dart';

/// Glides a [MapController] to a new camera instead of jumping there.
///
/// Positions are blended in projected (Web Mercator) space so the path is a
/// straight line on screen. A long trip zooms out on the way, so the user
/// sees where the map is going. A user gesture should call [stop].
class MapCameraAnimator {
  MapCameraAnimator(this._controller, TickerProvider vsync)
    : _animation = AnimationController(vsync: vsync, duration: Motion.long);

  final MapController _controller;
  final AnimationController _animation;
  VoidCallback? _tick;

  bool get isAnimating => _animation.isAnimating;

  /// Moves to [center] at [zoom]. [rotation] defaults to the current one.
  /// With [reduced] (reduced motion) it jumps.
  void moveTo(
    LatLng center,
    double zoom, {
    double? rotation,
    bool reduced = false,
  }) {
    stop();
    final from = _controller.camera;
    final endRotation = rotation ?? from.rotation;
    // Jump when asked to, or before the map has a size to measure trips in.
    if (reduced || from.nonRotatedSize.isEmpty) {
      _controller.moveAndRotate(center, zoom, endRotation);
      return;
    }

    final startPoint = from.projectAtZoom(from.center, 0);
    final endPoint = from.projectAtZoom(center, 0);
    final startZoom = from.zoom;

    // How far the trip is in screens at the lower zoom; beyond one screen,
    // zoom out midway by up to 3 levels.
    final lowZoom = math.min(startZoom, zoom);
    final scale = math.pow(2, lowZoom).toDouble();
    final screens =
        (endPoint - startPoint).distance *
        scale /
        from.nonRotatedSize.longestSide;
    final dip = screens > 1
        ? (math.log(screens) / math.ln2).clamp(0.0, 3.0)
        : 0.0;

    // Turn the short way round.
    final turn = ((endRotation - from.rotation + 540) % 360) - 180;
    final startRotation = from.rotation;

    void tick() {
      final t = Motion.standard.transform(_animation.value);
      final point = Offset.lerp(startPoint, endPoint, t)!;
      final z =
          startZoom + (zoom - startZoom) * t - dip * math.sin(math.pi * t);
      _controller.moveAndRotate(
        from.unprojectAtZoom(point, 0),
        z,
        startRotation + turn * t,
      );
    }

    _tick = tick;
    _animation
      ..duration = dip > 0 ? Motion.long * 1.5 : Motion.long
      ..addListener(tick);
    _animation.forward(from: 0).whenCompleteOrCancel(() {
      if (_tick == tick) {
        _animation.removeListener(tick);
        _tick = null;
      }
    });
  }

  /// Moves so [bounds] fill the view, inset by [padding], no closer than
  /// [maxZoom].
  void fitBounds(
    LatLngBounds bounds, {
    EdgeInsets padding = EdgeInsets.zero,
    double? maxZoom,
    bool reduced = false,
  }) {
    final fitted = CameraFit.bounds(
      bounds: bounds,
      padding: padding,
      maxZoom: maxZoom ?? double.infinity,
    ).fit(_controller.camera);
    moveTo(fitted.center, fitted.zoom, reduced: reduced);
  }

  /// Leaves the camera where it is now.
  void stop() {
    final tick = _tick;
    if (tick == null) return;
    _tick = null;
    _animation
      ..stop()
      ..removeListener(tick);
  }

  void dispose() {
    stop();
    _animation.dispose();
  }
}

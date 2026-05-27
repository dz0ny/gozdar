import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class RtkPosition {
  final LatLng point;
  final double? altitude;
  final double? hdop;
  final double? accuracyMeters;
  final int? fixQuality;
  final int? satellites;
  final DateTime updatedAt;

  const RtkPosition({
    required this.point,
    required this.updatedAt,
    this.altitude,
    this.hdop,
    this.accuracyMeters,
    this.fixQuality,
    this.satellites,
  });

  bool get isFresh => DateTime.now().difference(updatedAt) < const Duration(seconds: 10);
}

class RtkPositionService extends ChangeNotifier {
  RtkPosition? _position;

  RtkPosition? get position {
    final value = _position;
    if (value == null || !value.isFresh) return null;
    return value;
  }

  bool get hasFreshPosition => position != null;

  void update({
    required double latitude,
    required double longitude,
    double? altitude,
    double? hdop,
    double? accuracyMeters,
    int? fixQuality,
    int? satellites,
  }) {
    _position = RtkPosition(
      point: LatLng(latitude, longitude),
      altitude: altitude,
      hdop: hdop,
      accuracyMeters: accuracyMeters,
      fixQuality: fixQuality,
      satellites: satellites,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void clear() {
    _position = null;
    notifyListeners();
  }
}

final rtkPositionService = RtkPositionService();

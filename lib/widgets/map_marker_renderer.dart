import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_location.dart';
import '../models/parcel.dart';
import '../models/log_entry.dart';
import '../widgets/location_pointer.dart';

/// Handles rendering of various map markers
class MapMarkerRenderer {
  final double currentZoom;
  final List<MapLocation> locations;
  final List<Parcel> parcels;
  final List<LogEntry> geolocatedLogs;
  final LatLng? userPosition;
  final double? userHeading;
  final Color primaryColor;
  final Function(LatLng point, String name)? onLocationTap;
  final Function(MapLocation location)? onLocationLongPress;
  final Function(LatLng point, String name)? onLogTap;
  final Function(LatLng point, String name)? onParcelVertexTap;

  const MapMarkerRenderer({
    required this.currentZoom,
    required this.locations,
    required this.parcels,
    required this.geolocatedLogs,
    required this.userPosition,
    required this.userHeading,
    required this.primaryColor,
    this.onLocationTap,
    this.onLocationLongPress,
    this.onLogTap,
    this.onParcelVertexTap,
  });

  /// Check if markers should be visible at current zoom
  bool get showMarkers {
    return currentZoom >= 15; // Standard Web Mercator threshold
  }

  /// Get dynamic marker size based on zoom level
  double getMarkerSize(double baseSize) {
    const minZoom = 7.0;
    const maxZoom = 18.0;
    final zoomFactor = ((currentZoom - minZoom) / (maxZoom - minZoom)).clamp(
      0.0,
      1.0,
    );
    return baseSize * (0.5 + 0.5 * zoomFactor);
  }

  /// Build markers for saved locations
  List<Marker> buildLocationMarkers() {
    if (!showMarkers) return [];

    return locations.map((location) {
      final size = getMarkerSize(30);
      final point = LatLng(location.latitude, location.longitude);
      return Marker(
        point: point,
        width: size,
        height: size,
        child: GestureDetector(
          onTap: onLocationTap != null
              ? () => onLocationTap!(point, location.name)
              : null,
          onLongPress: onLocationLongPress != null
              ? () => onLocationLongPress!(location)
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: location.isSecnja ? Colors.orange : Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              location.isSecnja ? Icons.forest : Icons.location_on,
              color: Colors.white,
              size: size * 0.6,
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Build markers for parcel vertices (boundary points)
  List<Marker> buildParcelVertexMarkers() {
    if (!showMarkers) return [];

    final markers = <Marker>[];

    for (final parcel in parcels) {
      // Cadastral (imported) parcels are shown by the red kataster outline —
      // skip the green numbered boundary markers so they don't duplicate it.
      if (parcel.isCadastral) continue;
      for (int i = 0; i < parcel.polygon.length; i++) {
        final point = parcel.polygon[i];
        final pointName = parcel.getPointName(i);
        final size = getMarkerSize(28);
        final fontSize = getMarkerSize(12);
        final borderWidth = getMarkerSize(2);
        // Use a generous, zoom-independent tap target so the small boundary
        // markers (parcelni mejnik) are easy to hit, while the visual dot stays
        // sized to the zoom level.
        const hitSize = 48.0;

        markers.add(
          Marker(
            point: point,
            width: hitSize,
            height: hitSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onParcelVertexTap != null
                  ? () =>
                        onParcelVertexTap!(point, '$pointName (${parcel.name})')
                  : null,
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  /// Build markers for geolocated logs
  List<Marker> buildLogMarkers() {
    if (!showMarkers) return [];

    return geolocatedLogs.map((log) {
      final size = getMarkerSize(25);
      final point = LatLng(log.latitude!, log.longitude!);
      return Marker(
        point: point,
        width: size,
        height: size,
        child: GestureDetector(
          onTap: onLogTap != null
              ? () => onLogTap!(point, '${log.volume.toStringAsFixed(2)} m³')
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.brown,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.forest, color: Colors.white, size: size * 0.6),
          ),
        ),
      );
    }).toList();
  }

  /// Build user location marker
  Marker? buildUserLocationMarker() {
    if (userPosition == null) return null;

    final userSize = getMarkerSize(30);
    return Marker(
      point: userPosition!,
      width: userSize,
      height: userSize,
      child: LocationPointer(
        heading: userHeading,
        color: primaryColor,
        size: userSize,
      ),
    );
  }

  /// Get all markers combined
  List<Marker> getAllMarkers() {
    final markers = <Marker>[];

    // Location markers
    markers.addAll(buildLocationMarkers());

    // Parcel vertex markers
    markers.addAll(buildParcelVertexMarkers());

    // Log markers
    markers.addAll(buildLogMarkers());

    // User location marker
    final userMarker = buildUserLocationMarker();
    if (userMarker != null) {
      markers.add(userMarker);
    }

    return markers;
  }
}

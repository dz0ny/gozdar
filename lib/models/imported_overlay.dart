import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';

/// Imported overlay entity for storing roads, paths, and other line geometries
@Entity()
class ImportedOverlay {
  @Id()
  int id;

  /// Feature name or layer name
  String name;

  /// Original GeoPackage/file layer name
  String layerName;

  /// Geometry type ("LineString", "Polygon", "MultiLineString")
  String geometryType;

  /// Store geometry as JSON array of coordinate arrays
  /// LineString: [[lat1, lng1], [lat2, lng2], ...]
  /// MultiLineString: [[[lat1, lng1], [lat2, lng2]], [[lat3, lng3], ...]]
  /// Polygon: [[lat1, lng1], [lat2, lng2], ...] (outer ring only)
  String geometryJson;

  /// Optional properties from original feature (stored as JSON)
  String? properties;

  /// Color for rendering on map (stored as color value)
  int colorValue;

  /// Toggle visibility on map
  bool visible;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  ImportedOverlay({
    this.id = 0,
    required this.name,
    required this.layerName,
    required this.geometryType,
    required this.geometryJson,
    this.properties,
    int? colorValue,
    this.visible = true,
    DateTime? createdAt,
  }) : colorValue = colorValue ?? Colors.blue.toARGB32(),
       createdAt = createdAt ?? DateTime.now();

  /// Get geometry as List of LatLng lists (for LineString, MultiLineString, Polygon)
  @Transient()
  List<List<LatLng>> get geometry {
    if (geometryJson.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(geometryJson);

    // Handle different geometry types
    if (geometryType == 'LineString' || geometryType == 'Polygon') {
      // Single line/polygon: [[lat, lng], [lat, lng], ...]
      final coords = (decoded)
          .map((point) => LatLng(point[0] as double, point[1] as double))
          .toList();
      return [coords];
    } else if (geometryType == 'MultiLineString') {
      // Multiple lines: [[[lat, lng], ...], [[lat, lng], ...]]
      return decoded
          .map(
            (line) => (line as List)
                .map((point) => LatLng(point[0] as double, point[1] as double))
                .toList(),
          )
          .toList();
    }

    return [];
  }

  set geometry(List<List<LatLng>> value) {
    if (value.isEmpty) {
      geometryJson = '[]';
      return;
    }

    if (geometryType == 'LineString' || geometryType == 'Polygon') {
      // Store as single array of [lat, lng] pairs
      final coords = value.first.map((p) => [p.latitude, p.longitude]).toList();
      geometryJson = jsonEncode(coords);
    } else if (geometryType == 'MultiLineString') {
      // Store as array of arrays
      final lines = value
          .map((line) => line.map((p) => [p.latitude, p.longitude]).toList())
          .toList();
      geometryJson = jsonEncode(lines);
    }
  }

  /// Get color from stored value
  @Transient()
  Color get color => Color(colorValue);

  set color(Color value) => colorValue = value.toARGB32();

  /// Get properties as Map
  @Transient()
  Map<String, dynamic> get propertiesMap {
    if (properties == null || properties!.isEmpty) return {};
    return jsonDecode(properties!) as Map<String, dynamic>;
  }

  set propertiesMap(Map<String, dynamic> value) {
    properties = value.isEmpty ? null : jsonEncode(value);
  }
}

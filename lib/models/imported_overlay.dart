import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class ImportedOverlay {
  int id;
  String name;
  String layerName;
  String geometryType;
  String geometryJson;
  String? properties;
  int colorValue;
  bool visible;
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
  })  : colorValue = colorValue ?? Colors.blue.toARGB32(),
        createdAt = createdAt ?? DateTime.now();

  List<List<LatLng>> get geometry {
    if (geometryJson.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(geometryJson);
    if (geometryType == 'LineString' || geometryType == 'Polygon') {
      final coords = decoded
          .map((point) => LatLng(point[0] as double, point[1] as double))
          .toList();
      return [coords];
    } else if (geometryType == 'MultiLineString') {
      return decoded
          .map((line) => (line as List)
              .map((point) => LatLng(point[0] as double, point[1] as double))
              .toList())
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
      geometryJson = jsonEncode(value.first.map((p) => [p.latitude, p.longitude]).toList());
    } else if (geometryType == 'MultiLineString') {
      geometryJson = jsonEncode(
          value.map((line) => line.map((p) => [p.latitude, p.longitude]).toList()).toList());
    }
  }

  Color get color => Color(colorValue);
  set color(Color value) => colorValue = value.toARGB32();

  Map<String, dynamic> get propertiesMap {
    if (properties == null || properties!.isEmpty) return {};
    return jsonDecode(properties!) as Map<String, dynamic>;
  }

  set propertiesMap(Map<String, dynamic> value) {
    properties = value.isEmpty ? null : jsonEncode(value);
  }

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'name': name,
        'layer_name': layerName,
        'geometry_type': geometryType,
        'geometry_json': geometryJson,
        'properties': properties,
        'color_value': colorValue,
        'visible': visible ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ImportedOverlay.fromMap(Map<String, dynamic> map) => ImportedOverlay(
        id: map['id'] as int,
        name: map['name'] as String,
        layerName: map['layer_name'] as String,
        geometryType: map['geometry_type'] as String,
        geometryJson: map['geometry_json'] as String,
        properties: map['properties'] as String?,
        colorValue: map['color_value'] as int,
        visible: (map['visible'] as int) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

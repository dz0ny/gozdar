import 'dart:convert';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Forest type for parcel icon display
enum ForestType {
  mixed,     // Mešani gozd
  deciduous, // Listavci
  coniferous // Iglavci (smreka)
}

class Parcel {
  final int? id;
  final String name;
  final List<LatLng> polygon; // List of vertices
  final List<String?> pointNames; // Optional names for each vertex
  final DateTime createdAt;
  final int? cadastralMunicipality; // KO (katastrska obcina)
  final String? parcelNumber; // Parcel number from cadastre
  final String? owner; // Owner name
  final ForestType forestType; // Type of forest for icon display
  final double woodAllowance; // Allowed wood to cut in m³
  final double woodCut; // Wood already cut in m³
  final int treesCut; // Number of trees cut

  Parcel({
    this.id,
    required this.name,
    required this.polygon,
    List<String?>? pointNames,
    DateTime? createdAt,
    this.cadastralMunicipality,
    this.parcelNumber,
    this.owner,
    this.forestType = ForestType.mixed,
    this.woodAllowance = 0.0,
    this.woodCut = 0.0,
    this.treesCut = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       pointNames = pointNames ?? List.filled(polygon.length, null);

  /// Get display name for a point at given index
  String getPointName(int index) {
    if (index < 0 || index >= polygon.length) return 'Tocka ?';
    final customName = index < pointNames.length ? pointNames[index] : null;
    return customName ?? 'Tocka ${index + 1}';
  }

  /// Create a copy with updated point name
  Parcel withPointName(int index, String? name) {
    if (index < 0 || index >= polygon.length) return this;
    final newNames = List<String?>.from(pointNames);
    // Ensure list is long enough
    while (newNames.length < polygon.length) {
      newNames.add(null);
    }
    newNames[index] = name?.isEmpty == true ? null : name;
    return copyWith(pointNames: newNames);
  }

  /// Remaining wood allowance
  double get woodRemaining => (woodAllowance - woodCut).clamp(0.0, double.infinity);

  /// Percentage of allowance used
  double get woodUsedPercent => woodAllowance > 0 ? (woodCut / woodAllowance * 100).clamp(0.0, 100.0) : 0.0;

  /// Check if this is a cadastral parcel (imported from cadastre)
  bool get isCadastral => cadastralMunicipality != null && parcelNumber != null;

  /// Get unique cadastral ID (KO + parcel number)
  String? get cadastralId => isCadastral ? '$cadastralMunicipality/$parcelNumber' : null;

  /// Calculate area in square meters using the Shoelace formula
  /// with geodetic corrections for latitude
  double get areaM2 {
    if (polygon.length < 3) return 0.0;

    // Use the centroid latitude for the meter conversion
    final centerLat = polygon.map((p) => p.latitude).reduce((a, b) => a + b) / polygon.length;

    // Meters per degree at this latitude
    final metersPerDegreeLat = 111132.92 - 559.82 * math.cos(2 * centerLat * math.pi / 180) +
        1.175 * math.cos(4 * centerLat * math.pi / 180);
    final metersPerDegreeLon = 111412.84 * math.cos(centerLat * math.pi / 180) -
        93.5 * math.cos(3 * centerLat * math.pi / 180);

    // Convert to local meters and apply Shoelace formula
    double area = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;

      final x1 = polygon[i].longitude * metersPerDegreeLon;
      final y1 = polygon[i].latitude * metersPerDegreeLat;
      final x2 = polygon[j].longitude * metersPerDegreeLon;
      final y2 = polygon[j].latitude * metersPerDegreeLat;

      area += x1 * y2 - x2 * y1;
    }

    return (area.abs() / 2.0);
  }

  /// Get area formatted as string with appropriate unit
  String get areaFormatted {
    final area = areaM2;
    if (area >= 10000) {
      return '${(area / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${area.toStringAsFixed(0)} m²';
    }
  }

  /// Check if a point is inside this parcel using ray casting algorithm
  bool containsPoint(LatLng point) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Get the center point of the polygon
  LatLng get center {
    if (polygon.isEmpty) return const LatLng(0, 0);

    final avgLat = polygon.map((p) => p.latitude).reduce((a, b) => a + b) / polygon.length;
    final avgLng = polygon.map((p) => p.longitude).reduce((a, b) => a + b) / polygon.length;

    return LatLng(avgLat, avgLng);
  }

  Map<String, dynamic> toMap() {
    // Store polygon with optional point names in JSON
    final polygonData = <Map<String, dynamic>>[];
    for (int i = 0; i < polygon.length; i++) {
      final point = polygon[i];
      final pointData = <String, dynamic>{
        'lat': point.latitude,
        'lng': point.longitude,
      };
      // Only include name if it's set
      if (i < pointNames.length && pointNames[i] != null) {
        pointData['name'] = pointNames[i];
      }
      polygonData.add(pointData);
    }

    return {
      'id': id,
      'name': name,
      'polygon': jsonEncode(polygonData),
      'created_at': createdAt.toIso8601String(),
      'cadastral_municipality': cadastralMunicipality,
      'parcel_number': parcelNumber,
      'owner': owner,
      'forest_type': forestType.index,
      'wood_allowance': woodAllowance,
      'wood_cut': woodCut,
      'trees_cut': treesCut,
    };
  }

  factory Parcel.fromMap(Map<String, dynamic> map) {
    final polygonJson = jsonDecode(map['polygon'] as String) as List;
    final polygon = <LatLng>[];
    final pointNames = <String?>[];

    for (final p in polygonJson) {
      polygon.add(LatLng(p['lat'] as double, p['lng'] as double));
      // Extract point name if present (backward compatible)
      pointNames.add(p['name'] as String?);
    }

    final forestTypeIndex = map['forest_type'] as int? ?? 0;
    final forestType = forestTypeIndex < ForestType.values.length
        ? ForestType.values[forestTypeIndex]
        : ForestType.mixed;

    return Parcel(
      id: map['id'] as int?,
      name: map['name'] as String,
      polygon: polygon,
      pointNames: pointNames,
      createdAt: DateTime.parse(map['created_at'] as String),
      cadastralMunicipality: map['cadastral_municipality'] as int?,
      parcelNumber: map['parcel_number'] as String?,
      owner: map['owner'] as String?,
      forestType: forestType,
      woodAllowance: (map['wood_allowance'] as num?)?.toDouble() ?? 0.0,
      woodCut: (map['wood_cut'] as num?)?.toDouble() ?? 0.0,
      treesCut: (map['trees_cut'] as int?) ?? 0,
    );
  }

  Parcel copyWith({
    int? id,
    String? name,
    List<LatLng>? polygon,
    List<String?>? pointNames,
    DateTime? createdAt,
    int? cadastralMunicipality,
    String? parcelNumber,
    String? owner,
    ForestType? forestType,
    double? woodAllowance,
    double? woodCut,
    int? treesCut,
  }) {
    return Parcel(
      id: id ?? this.id,
      name: name ?? this.name,
      polygon: polygon ?? this.polygon,
      pointNames: pointNames ?? this.pointNames,
      createdAt: createdAt ?? this.createdAt,
      cadastralMunicipality: cadastralMunicipality ?? this.cadastralMunicipality,
      parcelNumber: parcelNumber ?? this.parcelNumber,
      owner: owner ?? this.owner,
      forestType: forestType ?? this.forestType,
      woodAllowance: woodAllowance ?? this.woodAllowance,
      woodCut: woodCut ?? this.woodCut,
      treesCut: treesCut ?? this.treesCut,
    );
  }
}

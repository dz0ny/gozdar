import 'dart:convert';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';
import 'log_entry.dart';

/// Forest type for parcel icon display
enum ForestType {
  mixed, // Mešani gozd
  deciduous, // Listavci
  coniferous // Iglavci (smreka)
}

@Entity()
class Parcel {
  @Id()
  int id;

  String name;

  // Store polygon as JSON string
  String polygonJson;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  int? cadastralMunicipality; // KO (katastrska obcina)
  String? parcelNumber; // Parcel number from cadastre
  String? owner; // Owner name

  // Store enum as int index
  int forestTypeIndex;

  double woodAllowance; // Allowed wood to cut in m³
  double woodCut; // Wood already cut in m³
  int treesCut; // Number of trees cut

  // Backlink to logs in this parcel
  @Backlink('parcel')
  final logs = ToMany<LogEntry>();

  // Transient: polygon as List<LatLng>
  @Transient()
  List<LatLng> get polygon {
    if (polygonJson.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(polygonJson);
    return decoded.map((p) => LatLng(p['lat'] as double, p['lng'] as double)).toList();
  }

  set polygon(List<LatLng> value) {
    final data = value.map((p) {
      final map = <String, dynamic>{'lat': p.latitude, 'lng': p.longitude};
      // Include point name if available
      final idx = value.indexOf(p);
      if (idx < _pointNames.length && _pointNames[idx] != null) {
        map['name'] = _pointNames[idx];
      }
      return map;
    }).toList();
    polygonJson = jsonEncode(data);
  }

  // Transient: point names
  @Transient()
  List<String?> _pointNames = [];

  @Transient()
  List<String?> get pointNames {
    if (polygonJson.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(polygonJson);
    return decoded.map((p) => p['name'] as String?).toList();
  }

  // Transient getter/setter for enum
  @Transient()
  ForestType get forestType => ForestType.values[forestTypeIndex];
  set forestType(ForestType value) => forestTypeIndex = value.index;

  Parcel({
    this.id = 0,
    required this.name,
    List<LatLng>? polygon,
    List<String?>? pointNames,
    DateTime? createdAt,
    this.cadastralMunicipality,
    this.parcelNumber,
    this.owner,
    ForestType forestType = ForestType.mixed,
    this.woodAllowance = 0.0,
    this.woodCut = 0.0,
    this.treesCut = 0,
    this.polygonJson = '[]',
  })  : forestTypeIndex = forestType.index,
        createdAt = createdAt ?? DateTime.now() {
    if (polygon != null) {
      _pointNames = pointNames ?? List.filled(polygon.length, null);
      _setPolygonWithNames(polygon, _pointNames);
    }
  }

  void _setPolygonWithNames(List<LatLng> polygonPoints, List<String?> names) {
    final data = <Map<String, dynamic>>[];
    for (int i = 0; i < polygonPoints.length; i++) {
      final point = polygonPoints[i];
      final map = <String, dynamic>{'lat': point.latitude, 'lng': point.longitude};
      if (i < names.length && names[i] != null) {
        map['name'] = names[i];
      }
      data.add(map);
    }
    polygonJson = jsonEncode(data);
  }

  /// Get display name for a point at given index
  String getPointName(int index) {
    final names = pointNames;
    if (index < 0 || index >= polygon.length) return 'Tocka ?';
    final customName = index < names.length ? names[index] : null;
    return customName ?? 'Tocka ${index + 1}';
  }

  /// Create a copy with updated point name
  Parcel withPointName(int index, String? name) {
    final currentPolygon = polygon;
    final currentNames = List<String?>.from(pointNames);
    if (index < 0 || index >= currentPolygon.length) return this;

    // Ensure list is long enough
    while (currentNames.length < currentPolygon.length) {
      currentNames.add(null);
    }
    currentNames[index] = name?.isEmpty == true ? null : name;
    return copyWith(polygon: currentPolygon, pointNames: currentNames);
  }

  /// Remaining wood allowance
  double get woodRemaining => (woodAllowance - woodCut).clamp(0.0, double.infinity);

  /// Percentage of allowance used
  double get woodUsedPercent =>
      woodAllowance > 0 ? (woodCut / woodAllowance * 100).clamp(0.0, 100.0) : 0.0;

  /// Check if this is a cadastral parcel (imported from cadastre)
  bool get isCadastral => cadastralMunicipality != null && parcelNumber != null;

  /// Get unique cadastral ID (KO + parcel number)
  String? get cadastralId => isCadastral ? '$cadastralMunicipality/$parcelNumber' : null;

  /// Calculate area in square meters using the Shoelace formula
  /// with geodetic corrections for latitude
  double get areaM2 {
    final poly = polygon;
    if (poly.length < 3) return 0.0;

    // Use the centroid latitude for the meter conversion
    final centerLat = poly.map((p) => p.latitude).reduce((a, b) => a + b) / poly.length;

    // Meters per degree at this latitude
    final metersPerDegreeLat = 111132.92 -
        559.82 * math.cos(2 * centerLat * math.pi / 180) +
        1.175 * math.cos(4 * centerLat * math.pi / 180);
    final metersPerDegreeLon = 111412.84 * math.cos(centerLat * math.pi / 180) -
        93.5 * math.cos(3 * centerLat * math.pi / 180);

    // Convert to local meters and apply Shoelace formula
    double area = 0.0;
    for (int i = 0; i < poly.length; i++) {
      final j = (i + 1) % poly.length;

      final x1 = poly[i].longitude * metersPerDegreeLon;
      final y1 = poly[i].latitude * metersPerDegreeLat;
      final x2 = poly[j].longitude * metersPerDegreeLon;
      final y2 = poly[j].latitude * metersPerDegreeLat;

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
    final poly = polygon;
    if (poly.length < 3) return false;

    bool inside = false;
    int j = poly.length - 1;

    for (int i = 0; i < poly.length; i++) {
      final xi = poly[i].longitude;
      final yi = poly[i].latitude;
      final xj = poly[j].longitude;
      final yj = poly[j].latitude;

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
    final poly = polygon;
    if (poly.isEmpty) return const LatLng(0, 0);

    final avgLat = poly.map((p) => p.latitude).reduce((a, b) => a + b) / poly.length;
    final avgLng = poly.map((p) => p.longitude).reduce((a, b) => a + b) / poly.length;

    return LatLng(avgLat, avgLng);
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

import 'dart:convert';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'log_entry.dart';

enum ForestType { mixed, deciduous, coniferous }

class Parcel {
  int id;
  String name;
  String polygonJson;
  DateTime createdAt;
  int? cadastralMunicipality;
  String? parcelNumber;
  String? owner;
  String? notes;
  int forestTypeIndex;
  double woodAllowance;
  double woodCut;
  int treesCut;

  // Populated externally when needed
  List<LogEntry> logs = [];

  List<LatLng> get polygon {
    if (polygonJson.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(polygonJson);
    return decoded.map((p) => LatLng(p['lat'] as double, p['lng'] as double)).toList();
  }

  set polygon(List<LatLng> value) {
    final data = value.map((p) => <String, dynamic>{'lat': p.latitude, 'lng': p.longitude}).toList();
    polygonJson = jsonEncode(data);
  }

  List<String?> get pointNames {
    if (polygonJson.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(polygonJson);
    return decoded.map((p) => p['name'] as String?).toList();
  }

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
    this.notes,
    ForestType forestType = ForestType.mixed,
    this.woodAllowance = 0.0,
    this.woodCut = 0.0,
    this.treesCut = 0,
    this.polygonJson = '[]',
  })  : forestTypeIndex = forestType.index,
        createdAt = createdAt ?? DateTime.now() {
    if (polygon != null) {
      _setPolygonWithNames(polygon, pointNames ?? List.filled(polygon.length, null));
    }
  }

  void _setPolygonWithNames(List<LatLng> polygonPoints, List<String?> names) {
    final data = <Map<String, dynamic>>[];
    for (int i = 0; i < polygonPoints.length; i++) {
      final p = polygonPoints[i];
      final map = <String, dynamic>{'lat': p.latitude, 'lng': p.longitude};
      if (i < names.length && names[i] != null) map['name'] = names[i];
      data.add(map);
    }
    polygonJson = jsonEncode(data);
  }

  String getPointName(int index) {
    final names = pointNames;
    if (index < 0 || index >= polygon.length) return 'Tocka ?';
    final customName = index < names.length ? names[index] : null;
    return customName ?? 'Tocka ${index + 1}';
  }

  Parcel withPointName(int index, String? name) {
    final currentPolygon = polygon;
    final currentNames = List<String?>.from(pointNames);
    if (index < 0 || index >= currentPolygon.length) return this;
    while (currentNames.length < currentPolygon.length) { currentNames.add(null); }
    currentNames[index] = name?.isEmpty == true ? null : name;
    return copyWith(polygon: currentPolygon, pointNames: currentNames);
  }

  double get woodRemaining => (woodAllowance - woodCut).clamp(0.0, double.infinity);
  double get woodUsedPercent =>
      woodAllowance > 0 ? (woodCut / woodAllowance * 100).clamp(0.0, 100.0) : 0.0;
  bool get isCadastral => cadastralMunicipality != null && parcelNumber != null;
  String? get cadastralId => isCadastral ? '$cadastralMunicipality/$parcelNumber' : null;

  double get areaM2 {
    final poly = polygon;
    if (poly.length < 3) return 0.0;
    final centerLat = poly.map((p) => p.latitude).reduce((a, b) => a + b) / poly.length;
    final metersPerDegreeLat = 111132.92 -
        559.82 * math.cos(2 * centerLat * math.pi / 180) +
        1.175 * math.cos(4 * centerLat * math.pi / 180);
    final metersPerDegreeLon = 111412.84 * math.cos(centerLat * math.pi / 180) -
        93.5 * math.cos(3 * centerLat * math.pi / 180);
    double area = 0.0;
    for (int i = 0; i < poly.length; i++) {
      final j = (i + 1) % poly.length;
      final x1 = poly[i].longitude * metersPerDegreeLon;
      final y1 = poly[i].latitude * metersPerDegreeLat;
      final x2 = poly[j].longitude * metersPerDegreeLon;
      final y2 = poly[j].latitude * metersPerDegreeLat;
      area += x1 * y2 - x2 * y1;
    }
    return area.abs() / 2.0;
  }

  String get areaFormatted {
    final area = areaM2;
    return area >= 10000
        ? '${(area / 10000).toStringAsFixed(2)} ha'
        : '${area.toStringAsFixed(0)} m²';
  }

  bool containsPoint(LatLng point) {
    final poly = polygon;
    if (poly.length < 3) return false;
    bool inside = false;
    int j = poly.length - 1;
    for (int i = 0; i < poly.length; i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

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
    String? notes,
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
      notes: notes ?? this.notes,
      forestType: forestType ?? this.forestType,
      woodAllowance: woodAllowance ?? this.woodAllowance,
      woodCut: woodCut ?? this.woodCut,
      treesCut: treesCut ?? this.treesCut,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'name': name,
        'polygon_json': polygonJson,
        'created_at': createdAt.millisecondsSinceEpoch,
        'cadastral_municipality': cadastralMunicipality,
        'parcel_number': parcelNumber,
        'owner': owner,
        'notes': notes,
        'forest_type_index': forestTypeIndex,
        'wood_allowance': woodAllowance,
        'wood_cut': woodCut,
        'trees_cut': treesCut,
      };

  factory Parcel.fromMap(Map<String, dynamic> map) => Parcel(
        id: map['id'] as int,
        name: map['name'] as String,
        polygonJson: map['polygon_json'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        cadastralMunicipality: map['cadastral_municipality'] as int?,
        parcelNumber: map['parcel_number'] as String?,
        owner: map['owner'] as String?,
        notes: map['notes'] as String?,
        forestType: ForestType.values[map['forest_type_index'] as int],
        woodAllowance: (map['wood_allowance'] as num).toDouble(),
        woodCut: (map['wood_cut'] as num).toDouble(),
        treesCut: map['trees_cut'] as int,
      );
}

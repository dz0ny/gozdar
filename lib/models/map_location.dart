/// Type of map location/POI
enum LocationType {
  /// General saved location (mejnik, skladišče, etc.)
  point,

  /// Tree marked for cutting (sečnja)
  secnja,
}

class MapLocation {
  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final LocationType type;
  final DateTime createdAt;

  MapLocation({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.type = LocationType.point,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Check if this is a sečnja (tree to cut) marker
  bool get isSecnja => type == LocationType.secnja;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MapLocation.fromMap(Map<String, dynamic> map) {
    return MapLocation(
      id: map['id'] as int?,
      name: map['name'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      type: _parseLocationType(map['type'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static LocationType _parseLocationType(String? typeStr) {
    if (typeStr == null) return LocationType.point;
    return LocationType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => LocationType.point,
    );
  }

  MapLocation copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    LocationType? type,
    DateTime? createdAt,
  }) {
    return MapLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MapLocation {
  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  MapLocation({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MapLocation.fromMap(Map<String, dynamic> map) {
    return MapLocation(
      id: map['id'] as int?,
      name: map['name'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  MapLocation copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) {
    return MapLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

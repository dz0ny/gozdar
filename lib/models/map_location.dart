enum LocationType { point, secnja }

class MapLocation {
  int id;
  String name;
  double latitude;
  double longitude;
  int typeIndex;
  DateTime createdAt;

  LocationType get type => LocationType.values[typeIndex];
  set type(LocationType value) => typeIndex = value.index;

  MapLocation({
    this.id = 0,
    required this.name,
    required this.latitude,
    required this.longitude,
    LocationType type = LocationType.point,
    DateTime? createdAt,
  })  : typeIndex = type.index,
        createdAt = createdAt ?? DateTime.now();

  bool get isSecnja => type == LocationType.secnja;

  MapLocation copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    LocationType? type,
    DateTime? createdAt,
  }) =>
      MapLocation(
        id: id ?? this.id,
        name: name ?? this.name,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'type_index': typeIndex,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory MapLocation.fromMap(Map<String, dynamic> map) => MapLocation(
        id: map['id'] as int,
        name: map['name'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        type: LocationType.values[map['type_index'] as int],
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

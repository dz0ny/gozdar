import 'package:objectbox/objectbox.dart';

/// Type of map location/POI
enum LocationType {
  /// General saved location (mejnik, skladišče, etc.)
  point,

  /// Tree marked for cutting (sečnja)
  secnja,
}

@Entity()
class MapLocation {
  @Id()
  int id;

  String name;
  double latitude;
  double longitude;

  // Store enum as int index
  int typeIndex;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  // Transient getter/setter for enum
  @Transient()
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

  /// Check if this is a sečnja (tree to cut) marker
  bool get isSecnja => type == LocationType.secnja;

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

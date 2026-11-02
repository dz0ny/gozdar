enum LocationType { point, secnja }

class MapLocation {
  int id;
  String name;
  double latitude;
  double longitude;
  int typeIndex;
  DateTime createdAt;

  /// Parcel a sečnja mark belongs to. Null for plain points and for marks
  /// outside every saved parcel.
  int? parcelId;

  /// Share link this mark came from. Null for marks made on this phone.
  String? sourceShareId;

  LocationType get type => LocationType.values[typeIndex];
  set type(LocationType value) => typeIndex = value.index;

  MapLocation({
    this.id = 0,
    required this.name,
    required this.latitude,
    required this.longitude,
    LocationType type = LocationType.point,
    DateTime? createdAt,
    this.parcelId,
    this.sourceShareId,
  }) : typeIndex = type.index,
       createdAt = createdAt ?? DateTime.now();

  bool get isSecnja => type == LocationType.secnja;

  MapLocation copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    LocationType? type,
    DateTime? createdAt,
    int? parcelId,
  }) => MapLocation(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    parcelId: parcelId ?? this.parcelId,
    sourceShareId: sourceShareId,
  );

  Map<String, dynamic> toMap() => {
    'id': id == 0 ? null : id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'type_index': typeIndex,
    'created_at': createdAt.millisecondsSinceEpoch,
    'parcel_id': parcelId,
    'source_share_id': sourceShareId,
  };

  factory MapLocation.fromMap(Map<String, dynamic> map) => MapLocation(
    id: map['id'] as int,
    name: map['name'] as String,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    type: LocationType.values[map['type_index'] as int],
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    parcelId: map['parcel_id'] as int?,
    sourceShareId: map['source_share_id'] as String?,
  );
}

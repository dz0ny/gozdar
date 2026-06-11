class LogBatch {
  int id;
  String? owner;
  String? notes;
  double? latitude;
  double? longitude;
  double totalVolume;
  int logCount;
  DateTime createdAt;

  LogBatch({
    this.id = 0,
    this.owner,
    this.notes,
    this.latitude,
    this.longitude,
    required this.totalVolume,
    required this.logCount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasLocation => latitude != null && longitude != null;

  LogBatch copyWith({
    int? id,
    String? owner,
    String? notes,
    double? latitude,
    double? longitude,
    double? totalVolume,
    int? logCount,
    DateTime? createdAt,
    bool clearOwner = false,
    bool clearNotes = false,
    bool clearLocation = false,
  }) =>
      LogBatch(
        id: id ?? this.id,
        owner: clearOwner ? null : (owner ?? this.owner),
        notes: clearNotes ? null : (notes ?? this.notes),
        latitude: clearLocation ? null : (latitude ?? this.latitude),
        longitude: clearLocation ? null : (longitude ?? this.longitude),
        totalVolume: totalVolume ?? this.totalVolume,
        logCount: logCount ?? this.logCount,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'owner': owner,
        'notes': notes,
        'latitude': latitude,
        'longitude': longitude,
        'total_volume': totalVolume,
        'log_count': logCount,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory LogBatch.fromMap(Map<String, dynamic> map) => LogBatch(
        id: map['id'] as int,
        owner: map['owner'] as String?,
        notes: map['notes'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        totalVolume: (map['total_volume'] as num).toDouble(),
        logCount: map['log_count'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

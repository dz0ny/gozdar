/// Saved batch of logs with metadata
class LogBatch {
  final int? id;
  final String? owner; // lastnik
  final String? notes; // opombe
  final double? latitude;
  final double? longitude;
  final double totalVolume; // m³
  final int logCount;
  final DateTime createdAt;

  LogBatch({
    this.id,
    this.owner,
    this.notes,
    this.latitude,
    this.longitude,
    required this.totalVolume,
    required this.logCount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner': owner,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'total_volume': totalVolume,
      'log_count': logCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LogBatch.fromMap(Map<String, dynamic> map) {
    return LogBatch(
      id: map['id'] as int?,
      owner: map['owner'] as String?,
      notes: map['notes'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      totalVolume: (map['total_volume'] as num).toDouble(),
      logCount: map['log_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  LogBatch copyWith({
    int? id,
    String? owner,
    String? notes,
    double? latitude,
    double? longitude,
    double? totalVolume,
    int? logCount,
    DateTime? createdAt,
  }) {
    return LogBatch(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      totalVolume: totalVolume ?? this.totalVolume,
      logCount: logCount ?? this.logCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

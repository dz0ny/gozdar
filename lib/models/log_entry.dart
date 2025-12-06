import 'dart:math' as math;

class LogEntry {
  final int? id;
  final double? diameter; // cm
  final double? length; // m
  final double volume; // m³
  final double? latitude;
  final double? longitude;
  final String? notes;
  final int? batchId; // Project/batch this log belongs to
  final int? parcelId; // Parcel this log is geolocated inside
  final DateTime createdAt;

  LogEntry({
    this.id,
    this.diameter,
    this.length,
    required this.volume,
    this.latitude,
    this.longitude,
    this.notes,
    this.batchId,
    this.parcelId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Calculate volume from diameter (cm) and length (m)
  /// Formula: V = π × (d/200)² × L
  /// where d/200 converts cm diameter to m radius
  static double calculateVolume(double diameterCm, double lengthM) {
    final radiusM = diameterCm / 200.0; // cm to m, diameter to radius
    return math.pi * radiusM * radiusM * lengthM;
  }

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'diameter': diameter,
      'length': length,
      'volume': volume,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'batch_id': batchId,
      'parcel_id': parcelId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'] as int?,
      diameter: map['diameter'] as double?,
      length: map['length'] as double?,
      volume: map['volume'] as double,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      notes: map['notes'] as String?,
      batchId: map['batch_id'] as int?,
      parcelId: map['parcel_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  LogEntry copyWith({
    int? id,
    double? diameter,
    double? length,
    double? volume,
    double? latitude,
    double? longitude,
    String? notes,
    int? batchId,
    int? parcelId,
    DateTime? createdAt,
  }) {
    return LogEntry(
      id: id ?? this.id,
      diameter: diameter ?? this.diameter,
      length: length ?? this.length,
      volume: volume ?? this.volume,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      batchId: batchId ?? this.batchId,
      parcelId: parcelId ?? this.parcelId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

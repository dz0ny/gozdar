import 'dart:math' as math;

class LogEntry {
  int id;
  double? diameter;
  double? length;
  double volume;
  double? latitude;
  double? longitude;
  String? notes;
  String? species;
  DateTime createdAt;
  int? batchId;
  int? parcelId;

  LogEntry({
    this.id = 0,
    this.diameter,
    this.length,
    required this.volume,
    this.latitude,
    this.longitude,
    this.notes,
    this.species,
    this.batchId,
    this.parcelId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static double calculateVolume(double diameterCm, double lengthM) {
    final radiusM = diameterCm / 200.0;
    return math.pi * radiusM * radiusM * lengthM;
  }

  bool get hasLocation => latitude != null && longitude != null;

  LogEntry copyWith({
    int? id,
    double? diameter,
    double? length,
    double? volume,
    double? latitude,
    double? longitude,
    String? notes,
    String? species,
    int? batchId,
    int? parcelId,
    DateTime? createdAt,
  }) =>
      LogEntry(
        id: id ?? this.id,
        diameter: diameter ?? this.diameter,
        length: length ?? this.length,
        volume: volume ?? this.volume,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        notes: notes ?? this.notes,
        species: species ?? this.species,
        batchId: batchId ?? this.batchId,
        parcelId: parcelId ?? this.parcelId,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'diameter': diameter,
        'length': length,
        'volume': volume,
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
        'species': species,
        'created_at': createdAt.millisecondsSinceEpoch,
        'batch_id': batchId,
        'parcel_id': parcelId,
      };

  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
        id: map['id'] as int,
        diameter: (map['diameter'] as num?)?.toDouble(),
        length: (map['length'] as num?)?.toDouble(),
        volume: (map['volume'] as num).toDouble(),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
        species: map['species'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        batchId: map['batch_id'] as int?,
        parcelId: map['parcel_id'] as int?,
      );
}

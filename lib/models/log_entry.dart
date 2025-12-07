import 'dart:math' as math;
import 'package:objectbox/objectbox.dart';
import 'log_batch.dart';
import 'parcel.dart';

@Entity()
class LogEntry {
  @Id()
  int id;

  double? diameter; // cm
  double? length; // m
  double volume; // m³
  double? latitude;
  double? longitude;
  String? notes;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  // Relations
  final batch = ToOne<LogBatch>();
  final parcel = ToOne<Parcel>();

  LogEntry({
    this.id = 0,
    this.diameter,
    this.length,
    required this.volume,
    this.latitude,
    this.longitude,
    this.notes,
    int? batchId,
    int? parcelId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (batchId != null && batchId != 0) {
      batch.targetId = batchId;
    }
    if (parcelId != null && parcelId != 0) {
      parcel.targetId = parcelId;
    }
  }

  /// Calculate volume from diameter (cm) and length (m)
  /// Formula: V = π × (d/200)² × L
  /// where d/200 converts cm diameter to m radius
  static double calculateVolume(double diameterCm, double lengthM) {
    final radiusM = diameterCm / 200.0; // cm to m, diameter to radius
    return math.pi * radiusM * radiusM * lengthM;
  }

  bool get hasLocation => latitude != null && longitude != null;

  // Convenience getters for relation IDs
  int? get batchId => batch.targetId == 0 ? null : batch.targetId;
  int? get parcelId => parcel.targetId == 0 ? null : parcel.targetId;

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
    final entry = LogEntry(
      id: id ?? this.id,
      diameter: diameter ?? this.diameter,
      length: length ?? this.length,
      volume: volume ?? this.volume,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
    // Copy relations
    if (batchId != null) {
      entry.batch.targetId = batchId;
    } else {
      entry.batch.targetId = batch.targetId;
    }
    if (parcelId != null) {
      entry.parcel.targetId = parcelId;
    } else {
      entry.parcel.targetId = parcel.targetId;
    }
    return entry;
  }
}

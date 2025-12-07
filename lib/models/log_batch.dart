import 'package:objectbox/objectbox.dart';
import 'log_entry.dart';

@Entity()
class LogBatch {
  @Id()
  int id;

  String? owner; // lastnik
  String? notes; // opombe
  double? latitude;
  double? longitude;
  double totalVolume; // m³
  int logCount;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  // Backlink to logs in this batch
  @Backlink('batch')
  final logs = ToMany<LogEntry>();

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

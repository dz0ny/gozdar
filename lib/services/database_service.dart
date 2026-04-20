import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../db/app_database.dart';
import '../models/log_batch.dart';
import '../models/log_entry.dart';
import '../models/map_location.dart';
import '../models/parcel.dart';
import '../models/imported_overlay.dart';

// ---------------------------------------------------------------------------
// Conversion helpers: drift row → app model
// ---------------------------------------------------------------------------

Parcel _parcelFromDb(DbParcel r) => Parcel(
      id: r.id,
      name: r.name,
      polygonJson: r.polygonJson,
      createdAt: r.createdAt,
      cadastralMunicipality: r.cadastralMunicipality,
      parcelNumber: r.parcelNumber,
      owner: r.owner,
      notes: r.notes,
      forestType: ForestType.values[r.forestTypeIndex],
      woodAllowance: r.woodAllowance,
      woodCut: r.woodCut,
      treesCut: r.treesCut,
    );

LogEntry _logFromDb(DbLogEntry r) => LogEntry(
      id: r.id,
      diameter: r.diameter,
      length: r.length,
      volume: r.volume,
      latitude: r.latitude,
      longitude: r.longitude,
      notes: r.notes,
      species: r.species,
      createdAt: r.createdAt,
      batchId: r.batchId,
      parcelId: r.parcelId,
    );

LogBatch _batchFromDb(DbLogBatch r) => LogBatch(
      id: r.id,
      owner: r.owner,
      notes: r.notes,
      latitude: r.latitude,
      longitude: r.longitude,
      totalVolume: r.totalVolume,
      logCount: r.logCount,
      createdAt: r.createdAt,
    );

MapLocation _locationFromDb(DbMapLocation r) => MapLocation(
      id: r.id,
      name: r.name,
      latitude: r.latitude,
      longitude: r.longitude,
      type: LocationType.values[r.typeIndex],
      createdAt: r.createdAt,
    );

ImportedOverlay _overlayFromDb(DbImportedOverlay r) => ImportedOverlay(
      id: r.id,
      name: r.name,
      layerName: r.layerName,
      geometryType: r.geometryType,
      geometryJson: r.geometryJson,
      properties: r.properties,
      colorValue: r.colorValue,
      visible: r.visible,
      createdAt: r.createdAt,
    );

// ---------------------------------------------------------------------------
// Conversion helpers: app model → drift companion
// ---------------------------------------------------------------------------

ParcelsCompanion _parcelToCompanion(Parcel p) => ParcelsCompanion(
      id: p.id == 0 ? const Value.absent() : Value(p.id),
      name: Value(p.name),
      polygonJson: Value(p.polygonJson),
      createdAt: Value(p.createdAt),
      cadastralMunicipality: Value(p.cadastralMunicipality),
      parcelNumber: Value(p.parcelNumber),
      owner: Value(p.owner),
      notes: Value(p.notes),
      forestTypeIndex: Value(p.forestTypeIndex),
      woodAllowance: Value(p.woodAllowance),
      woodCut: Value(p.woodCut),
      treesCut: Value(p.treesCut),
    );

LogEntriesCompanion _logToCompanion(LogEntry e) => LogEntriesCompanion(
      id: e.id == 0 ? const Value.absent() : Value(e.id),
      diameter: Value(e.diameter),
      length: Value(e.length),
      volume: Value(e.volume),
      latitude: Value(e.latitude),
      longitude: Value(e.longitude),
      notes: Value(e.notes),
      species: Value(e.species),
      createdAt: Value(e.createdAt),
      batchId: Value(e.batchId),
      parcelId: Value(e.parcelId),
    );

LogBatchesCompanion _batchToCompanion(LogBatch b) => LogBatchesCompanion(
      id: b.id == 0 ? const Value.absent() : Value(b.id),
      owner: Value(b.owner),
      notes: Value(b.notes),
      latitude: Value(b.latitude),
      longitude: Value(b.longitude),
      totalVolume: Value(b.totalVolume),
      logCount: Value(b.logCount),
      createdAt: Value(b.createdAt),
    );

MapLocationsCompanion _locationToCompanion(MapLocation l) => MapLocationsCompanion(
      id: l.id == 0 ? const Value.absent() : Value(l.id),
      name: Value(l.name),
      latitude: Value(l.latitude),
      longitude: Value(l.longitude),
      typeIndex: Value(l.typeIndex),
      createdAt: Value(l.createdAt),
    );

ImportedOverlaysCompanion _overlayToCompanion(ImportedOverlay o) => ImportedOverlaysCompanion(
      id: o.id == 0 ? const Value.absent() : Value(o.id),
      name: Value(o.name),
      layerName: Value(o.layerName),
      geometryType: Value(o.geometryType),
      geometryJson: Value(o.geometryJson),
      properties: Value(o.properties),
      colorValue: Value(o.colorValue),
      visible: Value(o.visible),
      createdAt: Value(o.createdAt),
    );

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static AppDatabase? _db;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  AppDatabase get db {
    if (_db == null) throw StateError('DatabaseService not initialized. Call initialize() first.');
    return _db!;
  }

  Future<void> initialize() async {
    if (_db != null) return;
    _db = AppDatabase();
  }

  @visibleForTesting
  void setDatabaseForTesting(AppDatabase database) {
    _db = database;
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    await _db?.close();
    _db = null;
  }

  // ==================== LOG OPERATIONS ====================

  Future<int> insertLog(LogEntry log) async {
    if (log.latitude != null && log.longitude != null && log.parcelId == null) {
      final parcel = await findContainingParcel(log.latitude!, log.longitude!);
      if (parcel != null) log = log.copyWith(parcelId: parcel.id);
    }
    return db.into(db.logEntries).insert(_logToCompanion(log));
  }

  Future<void> updateLog(LogEntry log) async {
    await db.update(db.logEntries).replace(_logToCompanion(log));
  }

  Future<void> deleteLog(int id) async {
    await (db.delete(db.logEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAllLogs() async {
    await db.delete(db.logEntries).go();
  }

  Future<List<LogEntry>> getAllLogs() async {
    final rows = await (db.select(db.logEntries)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(_logFromDb).toList();
  }

  Future<double> getTotalVolume() async {
    final rows = await (db.select(db.logEntries)..where((t) => t.batchId.isNull())).get();
    return rows.fold<double>(0.0, (sum, r) => sum + r.volume);
  }

  Future<List<LogEntry>> getUnassignedLogs() async {
    final rows = await (db.select(db.logEntries)
          ..where((t) => t.batchId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(_logFromDb).toList();
  }

  Future<List<LogEntry>> getLogsByBatch(int batchId) async {
    final rows = await (db.select(db.logEntries)
          ..where((t) => t.batchId.equals(batchId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(_logFromDb).toList();
  }

  Future<void> assignLogToBatch(int logId, int batchId) async {
    await (db.update(db.logEntries)..where((t) => t.id.equals(logId)))
        .write(LogEntriesCompanion(batchId: Value(batchId)));
  }

  Future<void> unassignLogFromBatch(int logId) async {
    await (db.update(db.logEntries)..where((t) => t.id.equals(logId)))
        .write(const LogEntriesCompanion(batchId: Value(null)));
  }

  Future<double> getBatchTotalVolume(int batchId) async {
    final rows =
        await (db.select(db.logEntries)..where((t) => t.batchId.equals(batchId))).get();
    return rows.fold<double>(0.0, (sum, r) => sum + r.volume);
  }

  Future<int> getBatchLogCount(int batchId) async {
    return db.logEntries.count(where: (t) => t.batchId.equals(batchId)).getSingle();
  }

  Future<List<LogEntry>> getLogsByParcel(int parcelId) async {
    final rows = await (db.select(db.logEntries)
          ..where((t) => t.parcelId.equals(parcelId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(_logFromDb).toList();
  }

  Future<double> getParcelTotalVolume(int parcelId) async {
    final rows =
        await (db.select(db.logEntries)..where((t) => t.parcelId.equals(parcelId))).get();
    return rows.fold<double>(0.0, (sum, r) => sum + r.volume);
  }

  Future<int> getParcelLogCount(int parcelId) async {
    return db.logEntries.count(where: (t) => t.parcelId.equals(parcelId)).getSingle();
  }

  Future<void> assignLogToParcel(int logId, int parcelId) async {
    await (db.update(db.logEntries)..where((t) => t.id.equals(logId)))
        .write(LogEntriesCompanion(parcelId: Value(parcelId)));
  }

  Future<void> unassignLogFromParcel(int logId) async {
    await (db.update(db.logEntries)..where((t) => t.id.equals(logId)))
        .write(const LogEntriesCompanion(parcelId: Value(null)));
  }

  Future<Parcel?> findContainingParcel(double latitude, double longitude) async {
    final parcels = await getAllParcels();
    final point = LatLng(latitude, longitude);
    for (final parcel in parcels) {
      if (parcel.containsPoint(point)) return parcel;
    }
    return null;
  }

  // ==================== LOG BATCH OPERATIONS ====================

  Future<int> insertLogBatch(LogBatch batch) async {
    return db.into(db.logBatches).insert(_batchToCompanion(batch));
  }

  Future<void> updateLogBatch(LogBatch batch) async {
    await db.update(db.logBatches).replace(_batchToCompanion(batch));
  }

  Future<void> deleteLogBatch(int id) async {
    await (db.delete(db.logBatches)..where((t) => t.id.equals(id))).go();
  }

  Future<List<LogBatch>> getAllLogBatches() async {
    final rows = await (db.select(db.logBatches)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(_batchFromDb).toList();
  }

  // ==================== LOCATION OPERATIONS ====================

  Future<int> insertLocation(MapLocation location) async {
    return db.into(db.mapLocations).insert(_locationToCompanion(location));
  }

  Future<void> updateLocation(MapLocation location) async {
    await db.update(db.mapLocations).replace(_locationToCompanion(location));
  }

  Future<void> deleteLocation(int id) async {
    await (db.delete(db.mapLocations)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateLocationName(int id, String name) async {
    await (db.update(db.mapLocations)..where((t) => t.id.equals(id)))
        .write(MapLocationsCompanion(name: Value(name)));
  }

  Future<List<MapLocation>> getAllLocations() async {
    final rows = await (db.select(db.mapLocations)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(_locationFromDb).toList();
  }

  // ==================== PARCEL OPERATIONS ====================

  Future<Parcel?> findParcelByKoAndNumber(int? koNumber, String? parcelNumber) async {
    if (koNumber == null || parcelNumber == null) return null;
    final row = await (db.select(db.parcels)
          ..where((t) =>
              t.cadastralMunicipality.equals(koNumber) & t.parcelNumber.equals(parcelNumber)))
        .getSingleOrNull();
    return row == null ? null : _parcelFromDb(row);
  }

  Future<int> insertParcel(Parcel parcel) async {
    return db.into(db.parcels).insert(_parcelToCompanion(parcel));
  }

  Future<void> updateParcel(Parcel parcel) async {
    await db.update(db.parcels).replace(_parcelToCompanion(parcel));
  }

  Future<void> deleteParcel(int id) async {
    await (db.delete(db.parcels)..where((t) => t.id.equals(id))).go();
  }

  Future<Map<String, int>> deleteParcelWithContents(int id) async {
    final row = await (db.select(db.parcels)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return {'logs': 0, 'locations': 0};
    final parcel = _parcelFromDb(row);

    final logsDeleted =
        await (db.delete(db.logEntries)..where((t) => t.parcelId.equals(id))).go();

    final allLocations = await getAllLocations();
    int locationsDeleted = 0;
    for (final loc in allLocations) {
      if (parcel.containsPoint(LatLng(loc.latitude, loc.longitude))) {
        await (db.delete(db.mapLocations)..where((t) => t.id.equals(loc.id))).go();
        locationsDeleted++;
      }
    }

    await (db.delete(db.parcels)..where((t) => t.id.equals(id))).go();
    return {'logs': logsDeleted, 'locations': locationsDeleted};
  }

  Future<List<Parcel>> getAllParcels() async {
    final rows = await (db.select(db.parcels)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(_parcelFromDb).toList();
  }

  Future<double> getTotalParcelArea() async {
    final parcels = await getAllParcels();
    return parcels.fold<double>(0.0, (sum, p) => sum + p.areaM2);
  }

  Future<bool> cadastralParcelExists(int cadastralMunicipality, String parcelNumber) async {
    final count = await db.parcels
        .count(
            where: (t) =>
                t.cadastralMunicipality.equals(cadastralMunicipality) &
                t.parcelNumber.equals(parcelNumber))
        .getSingle();
    return count > 0;
  }

  Future<Parcel?> getCadastralParcel(int cadastralMunicipality, String parcelNumber) async {
    final row = await (db.select(db.parcels)
          ..where((t) =>
              t.cadastralMunicipality.equals(cadastralMunicipality) &
              t.parcelNumber.equals(parcelNumber)))
        .getSingleOrNull();
    return row == null ? null : _parcelFromDb(row);
  }

  // ==================== IMPORTED OVERLAY OPERATIONS ====================

  Future<int> insertOverlay(ImportedOverlay overlay) async {
    return db.into(db.importedOverlays).insert(_overlayToCompanion(overlay));
  }

  Future<void> updateOverlay(ImportedOverlay overlay) async {
    await db.update(db.importedOverlays).replace(_overlayToCompanion(overlay));
  }

  Future<void> deleteOverlay(int id) async {
    await (db.delete(db.importedOverlays)..where((t) => t.id.equals(id))).go();
  }

  Future<List<ImportedOverlay>> getAllOverlays() async {
    final rows = await (db.select(db.importedOverlays)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(_overlayFromDb).toList();
  }

  Future<List<ImportedOverlay>> getVisibleOverlays() async {
    final rows = await (db.select(db.importedOverlays)
          ..where((t) => t.visible.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(_overlayFromDb).toList();
  }

  Future<void> toggleOverlayVisibility(int id) async {
    final row = await (db.select(db.importedOverlays)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (db.update(db.importedOverlays)..where((t) => t.id.equals(id)))
        .write(ImportedOverlaysCompanion(visible: Value(!row.visible)));
  }

  Future<void> deleteAllOverlays() async {
    await db.delete(db.importedOverlays).go();
  }

  // ==================== UTILITY ====================

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

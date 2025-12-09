import 'package:latlong2/latlong.dart';
import '../objectbox.g.dart';
import '../models/log_batch.dart';
import '../models/log_entry.dart';
import '../models/map_location.dart';
import '../models/parcel.dart';
import '../models/imported_overlay.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Store? _store;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Store get store {
    if (_store == null) {
      throw StateError('DatabaseService not initialized. Call initialize() first.');
    }
    return _store!;
  }

  Box<LogEntry> get _logBox => store.box<LogEntry>();
  Box<LogBatch> get _batchBox => store.box<LogBatch>();
  Box<MapLocation> get _locationBox => store.box<MapLocation>();
  Box<Parcel> get _parcelBox => store.box<Parcel>();
  Box<ImportedOverlay> get _overlayBox => store.box<ImportedOverlay>();

  Future<void> initialize() async {
    if (_store != null) return;
    _store = await openStore();
  }

  // ==================== LOG OPERATIONS ====================

  /// Insert a log entry, automatically assigning it to a parcel if it has location
  Future<int> insertLog(LogEntry log) async {
    // Auto-assign parcel if log has location and no parcel assigned
    if (log.latitude != null && log.longitude != null && log.parcel.targetId == 0) {
      final containingParcel = await findContainingParcel(
        log.latitude!,
        log.longitude!,
      );
      if (containingParcel != null && containingParcel.id != 0) {
        log.parcel.targetId = containingParcel.id;
      }
    }
    return _logBox.put(log);
  }

  Future<void> updateLog(LogEntry log) async {
    _logBox.put(log);
  }

  Future<void> deleteLog(int id) async {
    _logBox.remove(id);
  }

  Future<void> deleteAllLogs() async {
    _logBox.removeAll();
  }

  Future<List<LogEntry>> getAllLogs() async {
    final query = _logBox.query()
      ..order(LogEntry_.createdAt, flags: Order.descending);
    return query.build().find();
  }

  Future<double> getTotalVolume() async {
    // Get logs where batch is not assigned (targetId == 0)
    final query = _logBox.query(LogEntry_.batch.equals(0)).build();
    final logs = query.find();
    query.close();
    double total = 0.0;
    for (final log in logs) {
      total += log.volume;
    }
    return total;
  }

  /// Get logs that are not assigned to any batch
  Future<List<LogEntry>> getUnassignedLogs() async {
    final query = _logBox.query(LogEntry_.batch.equals(0))
      ..order(LogEntry_.createdAt, flags: Order.descending);
    final built = query.build();
    final result = built.find();
    built.close();
    return result;
  }

  /// Get logs for a specific batch
  Future<List<LogEntry>> getLogsByBatch(int batchId) async {
    final query = _logBox.query(LogEntry_.batch.equals(batchId))
      ..order(LogEntry_.createdAt, flags: Order.descending);
    final built = query.build();
    final result = built.find();
    built.close();
    return result;
  }

  /// Assign a log to a batch
  Future<void> assignLogToBatch(int logId, int batchId) async {
    final log = _logBox.get(logId);
    if (log != null) {
      log.batch.targetId = batchId;
      _logBox.put(log);
    }
  }

  /// Unassign a log from its batch
  Future<void> unassignLogFromBatch(int logId) async {
    final log = _logBox.get(logId);
    if (log != null) {
      log.batch.targetId = 0;
      _logBox.put(log);
    }
  }

  /// Get total volume for a batch
  Future<double> getBatchTotalVolume(int batchId) async {
    final query = _logBox.query(LogEntry_.batch.equals(batchId)).build();
    final logs = query.find();
    query.close();
    double total = 0.0;
    for (final log in logs) {
      total += log.volume;
    }
    return total;
  }

  /// Get log count for a batch
  Future<int> getBatchLogCount(int batchId) async {
    final query = _logBox.query(LogEntry_.batch.equals(batchId)).build();
    final count = query.count();
    query.close();
    return count;
  }

  /// Get logs for a specific parcel
  Future<List<LogEntry>> getLogsByParcel(int parcelId) async {
    final query = _logBox.query(LogEntry_.parcel.equals(parcelId))
      ..order(LogEntry_.createdAt, flags: Order.descending);
    final built = query.build();
    final result = built.find();
    built.close();
    return result;
  }

  /// Get total volume for a specific parcel
  Future<double> getParcelTotalVolume(int parcelId) async {
    final query = _logBox.query(LogEntry_.parcel.equals(parcelId)).build();
    final logs = query.find();
    query.close();
    double total = 0.0;
    for (final log in logs) {
      total += log.volume;
    }
    return total;
  }

  /// Get log count for a specific parcel
  Future<int> getParcelLogCount(int parcelId) async {
    final query = _logBox.query(LogEntry_.parcel.equals(parcelId)).build();
    final count = query.count();
    query.close();
    return count;
  }

  /// Assign a log to a parcel
  Future<void> assignLogToParcel(int logId, int parcelId) async {
    final log = _logBox.get(logId);
    if (log != null) {
      log.parcel.targetId = parcelId;
      _logBox.put(log);
    }
  }

  /// Unassign a log from its parcel
  Future<void> unassignLogFromParcel(int logId) async {
    final log = _logBox.get(logId);
    if (log != null) {
      log.parcel.targetId = 0;
      _logBox.put(log);
    }
  }

  /// Find the parcel that contains a given point (lat/lng)
  /// Returns the parcel if found, null otherwise
  Future<Parcel?> findContainingParcel(
    double latitude,
    double longitude,
  ) async {
    final parcels = await getAllParcels();
    final point = LatLng(latitude, longitude);

    for (final parcel in parcels) {
      if (parcel.containsPoint(point)) {
        return parcel;
      }
    }
    return null;
  }

  // ==================== LOG BATCH OPERATIONS ====================

  Future<int> insertLogBatch(LogBatch batch) async {
    return _batchBox.put(batch);
  }

  Future<void> updateLogBatch(LogBatch batch) async {
    _batchBox.put(batch);
  }

  Future<void> deleteLogBatch(int id) async {
    _batchBox.remove(id);
  }

  Future<List<LogBatch>> getAllLogBatches() async {
    final query = _batchBox.query()
      ..order(LogBatch_.createdAt, flags: Order.descending);
    return query.build().find();
  }

  // ==================== LOCATION OPERATIONS ====================

  Future<int> insertLocation(MapLocation location) async {
    return _locationBox.put(location);
  }

  Future<void> updateLocation(MapLocation location) async {
    _locationBox.put(location);
  }

  Future<void> deleteLocation(int id) async {
    _locationBox.remove(id);
  }

  Future<void> updateLocationName(int id, String name) async {
    final location = _locationBox.get(id);
    if (location != null) {
      location.name = name;
      _locationBox.put(location);
    }
  }

  Future<List<MapLocation>> getAllLocations() async {
    final query = _locationBox.query()
      ..order(MapLocation_.createdAt, flags: Order.descending);
    return query.build().find();
  }

  // ==================== PARCEL OPERATIONS ====================

  /// Check if a parcel with the same KO and parcel number already exists
  Future<Parcel?> findParcelByKoAndNumber(int? koNumber, String? parcelNumber) async {
    if (koNumber == null || parcelNumber == null) return null;

    final query = _parcelBox.query(
      Parcel_.cadastralMunicipality.equals(koNumber) &
      Parcel_.parcelNumber.equals(parcelNumber)
    ).build();

    final result = query.findFirst();
    query.close();
    return result;
  }

  Future<int> insertParcel(Parcel parcel) async {
    return _parcelBox.put(parcel);
  }

  Future<void> updateParcel(Parcel parcel) async {
    _parcelBox.put(parcel);
  }

  Future<void> deleteParcel(int id) async {
    _parcelBox.remove(id);
  }

  /// Delete a parcel and all points (logs and locations) inside it
  /// Returns counts of deleted items: {'logs': n, 'locations': n}
  Future<Map<String, int>> deleteParcelWithContents(int id) async {
    final parcel = _parcelBox.get(id);
    if (parcel == null) {
      return {'logs': 0, 'locations': 0};
    }

    // Delete logs assigned to this parcel
    final logsQuery = _logBox.query(LogEntry_.parcel.equals(id)).build();
    final logsDeleted = logsQuery.remove();
    logsQuery.close();

    // Find and delete locations inside the parcel polygon
    final allLocations = await getAllLocations();
    int locationsDeleted = 0;
    for (final location in allLocations) {
      final point = LatLng(location.latitude, location.longitude);
      if (parcel.containsPoint(point)) {
        _locationBox.remove(location.id);
        locationsDeleted++;
      }
    }

    // Finally delete the parcel itself
    _parcelBox.remove(id);

    return {'logs': logsDeleted, 'locations': locationsDeleted};
  }

  Future<List<Parcel>> getAllParcels() async {
    final query = _parcelBox.query()
      ..order(Parcel_.createdAt, flags: Order.descending);
    return query.build().find();
  }

  Future<double> getTotalParcelArea() async {
    final parcels = await getAllParcels();
    double total = 0.0;
    for (final parcel in parcels) {
      total += parcel.areaM2;
    }
    return total;
  }

  /// Check if a cadastral parcel with given KO and parcel number already exists
  Future<bool> cadastralParcelExists(
    int cadastralMunicipality,
    String parcelNumber,
  ) async {
    final query = _parcelBox
        .query(Parcel_.cadastralMunicipality.equals(cadastralMunicipality) &
            Parcel_.parcelNumber.equals(parcelNumber))
        .build();
    final count = query.count();
    query.close();
    return count > 0;
  }

  /// Get existing cadastral parcel by KO and parcel number
  Future<Parcel?> getCadastralParcel(
    int cadastralMunicipality,
    String parcelNumber,
  ) async {
    final query = _parcelBox
        .query(Parcel_.cadastralMunicipality.equals(cadastralMunicipality) &
            Parcel_.parcelNumber.equals(parcelNumber))
        .build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  // ==================== IMPORTED OVERLAY OPERATIONS ====================

  Future<int> insertOverlay(ImportedOverlay overlay) async {
    return _overlayBox.put(overlay);
  }

  Future<void> updateOverlay(ImportedOverlay overlay) async {
    _overlayBox.put(overlay);
  }

  Future<void> deleteOverlay(int id) async {
    _overlayBox.remove(id);
  }

  Future<List<ImportedOverlay>> getAllOverlays() async {
    final query = _overlayBox.query()
      ..order(ImportedOverlay_.createdAt, flags: Order.descending);
    return query.build().find();
  }

  Future<List<ImportedOverlay>> getVisibleOverlays() async {
    final query = _overlayBox.query(ImportedOverlay_.visible.equals(true))
      ..order(ImportedOverlay_.createdAt, flags: Order.descending);
    return query.build().find();
  }

  Future<void> toggleOverlayVisibility(int id) async {
    final overlay = _overlayBox.get(id);
    if (overlay != null) {
      overlay.visible = !overlay.visible;
      _overlayBox.put(overlay);
    }
  }

  Future<void> deleteAllOverlays() async {
    _overlayBox.removeAll();
  }

  // ==================== UTILITY METHODS ====================

  Future<void> close() async {
    _store?.close();
    _store = null;
  }

  Future<void> deleteDatabase() async {
    _store?.close();
    _store = null;
    // ObjectBox doesn't have a direct delete method, but the store directory
    // can be deleted if needed
  }
}

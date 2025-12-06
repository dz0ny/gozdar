import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:latlong2/latlong.dart';
import '../models/log_batch.dart';
import '../models/log_entry.dart';
import '../models/map_location.dart';
import '../models/parcel.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'gozdar.db');

    return await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create logs table
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        diameter REAL,
        length REAL,
        volume REAL NOT NULL,
        latitude REAL,
        longitude REAL,
        notes TEXT,
        batch_id INTEGER,
        parcel_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (batch_id) REFERENCES log_batches (id) ON DELETE SET NULL,
        FOREIGN KEY (parcel_id) REFERENCES parcels (id) ON DELETE SET NULL
      )
    ''');

    // Create locations table
    await db.execute('''
      CREATE TABLE locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        type TEXT DEFAULT 'point',
        created_at TEXT NOT NULL
      )
    ''');

    // Create parcels table
    await db.execute('''
      CREATE TABLE parcels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        polygon TEXT NOT NULL,
        created_at TEXT NOT NULL,
        cadastral_municipality INTEGER,
        parcel_number TEXT,
        owner TEXT,
        forest_type INTEGER DEFAULT 0,
        wood_allowance REAL DEFAULT 0.0,
        wood_cut REAL DEFAULT 0.0,
        trees_cut INTEGER DEFAULT 0
      )
    ''');

    // Create unique index for cadastral parcels
    await db.execute('''
      CREATE UNIQUE INDEX idx_cadastral_parcel
      ON parcels(cadastral_municipality, parcel_number)
      WHERE cadastral_municipality IS NOT NULL AND parcel_number IS NOT NULL
    ''');

    // Create log_batches table (saved log summaries)
    await db.execute('''
      CREATE TABLE log_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner TEXT,
        notes TEXT,
        latitude REAL,
        longitude REAL,
        total_volume REAL NOT NULL,
        log_count INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add parcels table
      await db.execute('''
        CREATE TABLE parcels (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          polygon TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add cadastral fields to parcels table
      await db.execute(
        'ALTER TABLE parcels ADD COLUMN cadastral_municipality INTEGER',
      );
      await db.execute('ALTER TABLE parcels ADD COLUMN parcel_number TEXT');

      // Create unique index for cadastral parcels
      await db.execute('''
        CREATE UNIQUE INDEX idx_cadastral_parcel
        ON parcels(cadastral_municipality, parcel_number)
        WHERE cadastral_municipality IS NOT NULL AND parcel_number IS NOT NULL
      ''');
    }

    if (oldVersion < 4) {
      // Add owner and wood tracking fields to parcels table
      await db.execute('ALTER TABLE parcels ADD COLUMN owner TEXT');
      await db.execute(
        'ALTER TABLE parcels ADD COLUMN wood_allowance REAL DEFAULT 0.0',
      );
      await db.execute(
        'ALTER TABLE parcels ADD COLUMN wood_cut REAL DEFAULT 0.0',
      );
    }

    if (oldVersion < 5) {
      // Add trees cut count to parcels table
      await db.execute(
        'ALTER TABLE parcels ADD COLUMN trees_cut INTEGER DEFAULT 0',
      );
    }

    if (oldVersion < 6) {
      // Add forest type to parcels table (0=mixed, 1=deciduous, 2=coniferous)
      await db.execute(
        'ALTER TABLE parcels ADD COLUMN forest_type INTEGER DEFAULT 0',
      );
    }

    if (oldVersion < 7) {
      // Add log_batches table (saved log summaries)
      await db.execute('''
        CREATE TABLE log_batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          owner TEXT,
          notes TEXT,
          latitude REAL,
          longitude REAL,
          total_volume REAL NOT NULL,
          log_count INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 8) {
      // Add batch_id to logs table for project management
      await db.execute('ALTER TABLE logs ADD COLUMN batch_id INTEGER');
    }

    if (oldVersion < 9) {
      // Add parcel_id to logs table for parcel association
      await db.execute('ALTER TABLE logs ADD COLUMN parcel_id INTEGER');
    }

    if (oldVersion < 10) {
      // Add type to locations table for different POI types (point, secnja)
      await db.execute(
        "ALTER TABLE locations ADD COLUMN type TEXT DEFAULT 'point'",
      );
    }
  }

  Future<void> initialize() async {
    await database;
  }

  // ==================== LOG OPERATIONS ====================

  /// Insert a log entry, automatically assigning it to a parcel if it has location
  Future<int> insertLog(LogEntry log) async {
    final db = await database;

    // Auto-assign parcel if log has location and no parcel assigned
    LogEntry logToInsert = log;
    if (log.latitude != null && log.longitude != null && log.parcelId == null) {
      final containingParcel = await findContainingParcel(
        log.latitude!,
        log.longitude!,
      );
      if (containingParcel != null && containingParcel.id != null) {
        logToInsert = log.copyWith(parcelId: containingParcel.id);
      }
    }

    final map = logToInsert.toMap();
    map.remove('id'); // Remove id to let SQLite auto-increment
    return await db.insert('logs', map);
  }

  Future<void> updateLog(LogEntry log) async {
    final db = await database;
    await db.update('logs', log.toMap(), where: 'id = ?', whereArgs: [log.id]);
  }

  Future<void> deleteLog(int id) async {
    final db = await database;
    await db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllLogs() async {
    final db = await database;
    await db.delete('logs');
  }

  Future<List<LogEntry>> getAllLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logs',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => LogEntry.fromMap(map)).toList();
  }

  Future<double> getTotalVolume() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(volume) as total FROM logs WHERE batch_id IS NULL',
    );
    final total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }

  /// Get logs that are not assigned to any batch
  Future<List<LogEntry>> getUnassignedLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logs',
      where: 'batch_id IS NULL',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => LogEntry.fromMap(map)).toList();
  }

  /// Get logs for a specific batch
  Future<List<LogEntry>> getLogsByBatch(int batchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logs',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => LogEntry.fromMap(map)).toList();
  }

  /// Assign a log to a batch
  Future<void> assignLogToBatch(int logId, int batchId) async {
    final db = await database;
    await db.update(
      'logs',
      {'batch_id': batchId},
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  /// Unassign a log from its batch
  Future<void> unassignLogFromBatch(int logId) async {
    final db = await database;
    await db.update(
      'logs',
      {'batch_id': null},
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  /// Get total volume for a batch
  Future<double> getBatchTotalVolume(int batchId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(volume) as total FROM logs WHERE batch_id = ?',
      [batchId],
    );
    final total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }

  /// Get log count for a batch
  Future<int> getBatchLogCount(int batchId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM logs WHERE batch_id = ?',
      [batchId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get logs for a specific parcel
  Future<List<LogEntry>> getLogsByParcel(int parcelId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logs',
      where: 'parcel_id = ?',
      whereArgs: [parcelId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => LogEntry.fromMap(map)).toList();
  }

  /// Get total volume for a specific parcel
  Future<double> getParcelTotalVolume(int parcelId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(volume) as total FROM logs WHERE parcel_id = ?',
      [parcelId],
    );
    final total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }

  /// Get log count for a specific parcel
  Future<int> getParcelLogCount(int parcelId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM logs WHERE parcel_id = ?',
      [parcelId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Assign a log to a parcel
  Future<void> assignLogToParcel(int logId, int parcelId) async {
    final db = await database;
    await db.update(
      'logs',
      {'parcel_id': parcelId},
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  /// Unassign a log from its parcel
  Future<void> unassignLogFromParcel(int logId) async {
    final db = await database;
    await db.update(
      'logs',
      {'parcel_id': null},
      where: 'id = ?',
      whereArgs: [logId],
    );
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
    final db = await database;
    final map = batch.toMap();
    map.remove('id');
    return await db.insert('log_batches', map);
  }

  Future<void> updateLogBatch(LogBatch batch) async {
    final db = await database;
    await db.update(
      'log_batches',
      batch.toMap(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  Future<void> deleteLogBatch(int id) async {
    final db = await database;
    await db.delete('log_batches', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<LogBatch>> getAllLogBatches() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'log_batches',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => LogBatch.fromMap(map)).toList();
  }

  // ==================== LOCATION OPERATIONS ====================

  Future<int> insertLocation(MapLocation location) async {
    final db = await database;
    final map = location.toMap();
    map.remove('id'); // Remove id to let SQLite auto-increment
    return await db.insert('locations', map);
  }

  Future<void> updateLocation(MapLocation location) async {
    final db = await database;
    await db.update(
      'locations',
      location.toMap(),
      where: 'id = ?',
      whereArgs: [location.id],
    );
  }

  Future<void> deleteLocation(int id) async {
    final db = await database;
    await db.delete('locations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateLocationName(int id, String name) async {
    final db = await database;
    await db.update(
      'locations',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MapLocation>> getAllLocations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'locations',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => MapLocation.fromMap(map)).toList();
  }

  // ==================== PARCEL OPERATIONS ====================

  Future<int> insertParcel(Parcel parcel) async {
    final db = await database;
    final map = parcel.toMap();
    map.remove('id');
    return await db.insert('parcels', map);
  }

  Future<void> updateParcel(Parcel parcel) async {
    final db = await database;
    await db.update(
      'parcels',
      parcel.toMap(),
      where: 'id = ?',
      whereArgs: [parcel.id],
    );
  }

  Future<void> deleteParcel(int id) async {
    final db = await database;
    await db.delete('parcels', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete a parcel and all points (logs and locations) inside it
  /// Returns counts of deleted items: {'logs': n, 'locations': n}
  Future<Map<String, int>> deleteParcelWithContents(int id) async {
    final db = await database;

    // First get the parcel to check containment
    final parcelMaps = await db.query(
      'parcels',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (parcelMaps.isEmpty) {
      return {'logs': 0, 'locations': 0};
    }

    final parcel = Parcel.fromMap(parcelMaps.first);

    // Delete logs inside the parcel (by parcel_id assignment)
    final logsDeleted = await db.delete(
      'logs',
      where: 'parcel_id = ?',
      whereArgs: [id],
    );

    // Find and delete locations inside the parcel polygon
    final allLocations = await getAllLocations();
    int locationsDeleted = 0;
    for (final location in allLocations) {
      final point = LatLng(location.latitude, location.longitude);
      if (parcel.containsPoint(point)) {
        await db.delete('locations', where: 'id = ?', whereArgs: [location.id]);
        locationsDeleted++;
      }
    }

    // Finally delete the parcel itself
    await db.delete('parcels', where: 'id = ?', whereArgs: [id]);

    return {'logs': logsDeleted, 'locations': locationsDeleted};
  }

  Future<List<Parcel>> getAllParcels() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parcels',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Parcel.fromMap(map)).toList();
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
    final db = await database;
    final result = await db.query(
      'parcels',
      where: 'cadastral_municipality = ? AND parcel_number = ?',
      whereArgs: [cadastralMunicipality, parcelNumber],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get existing cadastral parcel by KO and parcel number
  Future<Parcel?> getCadastralParcel(
    int cadastralMunicipality,
    String parcelNumber,
  ) async {
    final db = await database;
    final result = await db.query(
      'parcels',
      where: 'cadastral_municipality = ? AND parcel_number = ?',
      whereArgs: [cadastralMunicipality, parcelNumber],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Parcel.fromMap(result.first);
  }

  // ==================== UTILITY METHODS ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'gozdar.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}

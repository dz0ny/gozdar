import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

@DataClassName('DbParcel')
class Parcels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get polygonJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get cadastralMunicipality => integer().nullable()();
  TextColumn get parcelNumber => text().nullable()();
  TextColumn get owner => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get forestTypeIndex => integer().withDefault(const Constant(0))();
  RealColumn get woodAllowance => real().withDefault(const Constant(0.0))();
  RealColumn get woodCut => real().withDefault(const Constant(0.0))();
  IntColumn get treesCut => integer().withDefault(const Constant(0))();
}

@DataClassName('DbLogBatch')
class LogBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get owner => text().nullable()();
  TextColumn get notes => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get totalVolume => real()();
  IntColumn get logCount => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('DbLogEntry')
class LogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get diameter => real().nullable()();
  RealColumn get length => real().nullable()();
  RealColumn get volume => real()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get species => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get batchId => integer().nullable().references(LogBatches, #id)();
  IntColumn get parcelId => integer().nullable().references(Parcels, #id)();
}

@DataClassName('DbMapLocation')
class MapLocations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get typeIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('DbImportedOverlay')
class ImportedOverlays extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get layerName => text()();
  TextColumn get geometryType => text()();
  TextColumn get geometryJson => text()();
  TextColumn get properties => text().nullable()();
  IntColumn get colorValue => integer()();
  BoolColumn get visible => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('DbHttpCacheEntry')
class HttpCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get urlHash => text().unique()();
  TextColumn get url => text()();
  TextColumn get responseBody => text()();
  IntColumn get statusCode => integer()();
  DateTimeColumn get cachedAt => dateTime()();
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Parcels, LogBatches, LogEntries, MapLocations, ImportedOverlays, HttpCache])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'gozdar',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}

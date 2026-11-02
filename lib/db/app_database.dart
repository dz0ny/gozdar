import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../models/map_location.dart';
import '../models/parcel.dart';

part 'app_database.g.dart';

/// Id of the smallest parcel in [parcels] that contains [point], or null.
int? smallestParcelAt(Iterable<Parcel> parcels, LatLng point) {
  Parcel? best;
  for (final p in parcels) {
    if (!p.containsPoint(point)) continue;
    if (best == null || p.areaM2 < best.areaM2) best = p;
  }
  return best?.id;
}

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
  // Sečnja share link, set while the owner shares this parcel's marks.
  TextColumn get shareId => text().nullable()();
  TextColumn get shareEditToken => text().nullable()();
  TextColumn get shareHash => text().nullable()();
  DateTimeColumn get sharedAt => dateTime().nullable()();
  DateTimeColumn get shareExpiresAt => dateTime().nullable()();
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
  // Parcel that a sečnja mark belongs to.
  IntColumn get parcelId => integer().nullable().references(Parcels, #id)();
  // Share link a sečnja mark came from; null for marks made on this phone.
  TextColumn get sourceShareId => text().nullable()();
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

@DataClassName('DbOfflineTileStyle')
class OfflineTileStyles extends Table {
  TextColumn get styleHash => text()();
  TextColumn get displayName => text()();
  TextColumn get urlTemplate => text()();
  TextColumn get regionJson => text().nullable()();
  IntColumn get tileCount => integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {styleHash};
}

@DataClassName('DbOfflineTileEntry')
class OfflineTileEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get styleHash =>
      text().references(OfflineTileStyles, #styleHash)();
  IntColumn get z => integer()();
  IntColumn get x => integer()();
  IntColumn get y => integer()();
  TextColumn get relativePath => text().nullable()();
  TextColumn get contentType => text().nullable()();
  IntColumn get sizeBytes => integer()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {styleHash, z, x, y},
  ];
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    Parcels,
    LogBatches,
    LogEntries,
    MapLocations,
    ImportedOverlays,
    HttpCache,
    OfflineTileStyles,
    OfflineTileEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(offlineTileStyles);
        await m.createTable(offlineTileEntries);
      }
      if (from >= 2 && from < 3) {
        await m.addColumn(offlineTileEntries, offlineTileEntries.relativePath);
        await m.addColumn(offlineTileEntries, offlineTileEntries.contentType);
      }
      if (from < 4) {
        // Deleting a project used to leave its logs pointing at a missing
        // batch, hiding them everywhere. Return them to the working list.
        await repairOrphanedLogs();
      }
      if (from < 5) {
        await _addColumnIfMissing(m, mapLocations, mapLocations.parcelId);
        await _addColumnIfMissing(m, parcels, parcels.shareId);
        await _addColumnIfMissing(m, parcels, parcels.shareEditToken);
        await _addColumnIfMissing(m, parcels, parcels.shareHash);
        await _addColumnIfMissing(m, parcels, parcels.sharedAt);
        await _addColumnIfMissing(m, parcels, parcels.shareExpiresAt);
        await backfillSecnjaParcels();
      }
      if (from < 6) {
        // Received shares now import as parcels; the list of them is gone.
        await _addColumnIfMissing(m, mapLocations, mapLocations.sourceShareId);
        await customStatement('DROP TABLE IF EXISTS received_shares');
      }
    },
  );

  /// Adds [column] unless the table has it already. A database that a
  /// failed upgrade left half done can then upgrade again.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final info = await customSelect(
      'PRAGMA table_info("${table.actualTableName}")',
    ).get();
    if (info.any((r) => r.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }

  /// Links sečnja marks without a parcel to the saved parcel under them.
  /// When parcels overlap, the smallest parcel gets the mark.
  Future<void> backfillSecnjaParcels() async {
    final rows =
        await (select(mapLocations)..where(
              (t) =>
                  t.parcelId.isNull() &
                  t.typeIndex.equals(LocationType.secnja.index),
            ))
            .get();
    if (rows.isEmpty) return;
    final saved = (await select(parcels).get())
        .map((r) => Parcel(id: r.id, name: r.name, polygonJson: r.polygonJson))
        .toList();
    for (final row in rows) {
      final id = smallestParcelAt(saved, LatLng(row.latitude, row.longitude));
      if (id == null) continue;
      await (update(mapLocations)..where((t) => t.id.equals(row.id))).write(
        MapLocationsCompanion(parcelId: Value(id)),
      );
    }
  }

  /// Returns logs whose project no longer exists to the working list.
  Future<int> repairOrphanedLogs() {
    return customUpdate(
      'UPDATE log_entries SET batch_id = NULL '
      'WHERE batch_id IS NOT NULL '
      'AND batch_id NOT IN (SELECT id FROM log_batches)',
      updates: {logEntries},
      updateKind: UpdateKind.update,
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'gozdar',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}

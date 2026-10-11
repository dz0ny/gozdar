import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/models/log_batch.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final service = DatabaseService();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service.setDatabaseForTesting(db);
  });

  tearDown(() => service.resetForTesting());

  Future<int> addBatch() =>
      service.insertLogBatch(LogBatch(totalVolume: 0, logCount: 0));

  Future<int> addLog({int? batchId}) =>
      service.insertLog(LogEntry(volume: 1, batchId: batchId));

  test('deleteAllLogs keeps logs saved in projects', () async {
    final batchId = await addBatch();
    await addLog();
    await addLog();
    await addLog(batchId: batchId);

    final deleted = await service.deleteAllLogs();

    expect(deleted, 2);
    expect(await service.getUnassignedLogs(), isEmpty);
    expect(await service.getLogsByBatch(batchId), hasLength(1));
  });

  test('deleteLogBatch returns its logs to the working list', () async {
    final batchId = await addBatch();
    final otherId = await addBatch();
    await addLog(batchId: batchId);
    await addLog(batchId: batchId);
    await addLog(batchId: otherId);

    await service.deleteLogBatch(batchId);

    expect(await service.getAllLogs(), hasLength(3));
    expect(await service.getUnassignedLogs(), hasLength(2));
    expect(await service.getLogsByBatch(otherId), hasLength(1));
    expect((await service.getAllLogBatches()).map((b) => b.id), [otherId]);
  });

  test('repairOrphanedLogs recovers logs hidden by older batch deletes', () async {
    final batchId = await addBatch();
    final keptId = await addBatch();
    await addLog(batchId: batchId);
    await addLog(batchId: keptId);
    // Simulate the old deleteLogBatch, which removed only the batch row.
    await (db.delete(db.logBatches)..where((t) => t.id.equals(batchId))).go();
    expect(await service.getUnassignedLogs(), isEmpty);

    final repaired = await db.repairOrphanedLogs();

    expect(repaired, 1);
    expect(await service.getUnassignedLogs(), hasLength(1));
    expect(await service.getLogsByBatch(keptId), hasLength(1));
  });

  test('upgrading from schema v3 returns orphaned logs to the list', () async {
    final dir = await Directory.systemTemp.createTemp('gozdar-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    // A v3 database where the old deleteLogBatch left a log orphaned.
    final old = AppDatabase(NativeDatabase(file));
    final batchId = await old.into(old.logBatches).insert(
          LogBatchesCompanion.insert(totalVolume: 1, logCount: 1, createdAt: DateTime.now()),
        );
    await old.into(old.logEntries).insert(
          LogEntriesCompanion.insert(volume: 1, createdAt: DateTime.now(), batchId: Value(batchId)),
        );
    await (old.delete(old.logBatches)..where((t) => t.id.equals(batchId))).go();
    await old.customStatement('PRAGMA user_version = 3');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    service.setDatabaseForTesting(upgraded);

    expect(await service.getUnassignedLogs(), hasLength(1));
  });
}

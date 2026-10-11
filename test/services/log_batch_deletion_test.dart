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
}

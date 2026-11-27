import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/models/log_entry.dart';
import 'package:gozdar/models/secnja_share.dart';
import 'package:gozdar/providers/logs_provider.dart';
import 'package:gozdar/providers/map_provider.dart';
import 'package:gozdar/providers/service_providers.dart';
import 'package:gozdar/services/database_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = DatabaseService();
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service.setDatabaseForTesting(AppDatabase(NativeDatabase.memory()));
    container = ProviderContainer(
      overrides: [databaseServiceProvider.overrideWithValue(service)],
    );
  });

  tearDown(() async {
    container.dispose();
    await service.resetForTesting();
  });

  /// Waits until [check] holds, for the loads started by build().
  Future<void> until(bool Function() check) async {
    for (var i = 0; i < 50 && !check(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(check(), isTrue);
  }

  test('logs load after build and mark the log added last', () async {
    await service.insertLog(LogEntry(volume: 1));

    // Reading starts the load without writing state during build.
    expect(container.read(logsNotifierProvider).isLoading, isTrue);
    await until(() => container.read(logsNotifierProvider).entryCount == 1);

    final notifier = container.read(logsNotifierProvider.notifier);
    expect(await notifier.addLogEntry(LogEntry(volume: 2)), isTrue);
    final state = container.read(logsNotifierProvider);
    expect(state.entryCount, 2);
    expect(state.totalVolume, 3);
    expect(
      state.lastAddedId,
      state.logEntries.firstWhere((e) => e.volume == 2).id,
    );
  });

  test('a focus request is handed out once', () async {
    final notifier = container.read(mapNotifierProvider.notifier);
    expect(notifier.takePendingFocus(), isNull);

    notifier.focusOn(
      SecnjaSharePayload(
        parcelNumber: '1/1',
        polygon: const [LatLng(46.0, 14.0), LatLng(46.001, 14.001)],
        createdAt: DateTime(2026),
      ),
    );
    final focus = notifier.takePendingFocus();
    expect(focus, isNotNull);
    expect(focus!.contains(const LatLng(46.0005, 14.0005)), isTrue);
    expect(notifier.takePendingFocus(), isNull);
  });
}

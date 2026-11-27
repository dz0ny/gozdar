import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/log_entry.dart';
import '../models/log_batch.dart';
import '../services/export_service.dart';
import '../services/species_service.dart';
import 'service_providers.dart';

part 'logs_provider.freezed.dart';

/// Conversion factors between solid wood (m³) and stacked/loose measures.
///
/// Each factor is the solid wood in one unit: 1 PRM × [prm] = m³ and
/// 1 NM × [nm] = m³. So converting m³ to PRM/NM divides by the factor.
@freezed
abstract class ConversionFactors with _$ConversionFactors {
  const ConversionFactors._();

  const factory ConversionFactors({
    @Default(0.65) double prm,
    @Default(0.40) double nm,
  }) = _ConversionFactors;

  /// Stacked metres (PRM) holding [solidM3] of solid wood.
  double toPrm(double solidM3) => prm > 0 ? solidM3 / prm : 0;

  /// Loose metres (NM) holding [solidM3] of solid wood.
  double toNm(double solidM3) => nm > 0 ? solidM3 / nm : 0;
}

/// What the Hlodi tab shows: the working list of logs and saved batches.
@freezed
abstract class LogsState with _$LogsState {
  const LogsState._();

  const factory LogsState({
    /// Logs not in any batch.
    @Default(<LogEntry>[]) List<LogEntry> logEntries,
    @Default(<LogBatch>[]) List<LogBatch> batches,
    @Default(0.0) double totalVolume,
    @Default(false) bool isLoading,
    @Default(false) bool isBatchesLoading,
    String? error,
    @Default(ConversionFactors()) ConversionFactors conversionFactors,

    /// Species assigned to logs added from the Hlodi tab (null = none).
    String? currentSpecies,

    /// Id of the log added last from this tab, so the list can scroll to it
    /// and mark it. Null until something is added.
    int? lastAddedId,
  }) = _LogsState;

  bool get hasEntries => logEntries.isNotEmpty;
  int get entryCount => logEntries.length;
  double get prmVolume => conversionFactors.toPrm(totalVolume);
  double get nmVolume => conversionFactors.toNm(totalVolume);
}

/// Logs state for the Hlodi tab. The getters read the current state, so a
/// callback that keeps the notifier sees fresh values after an await.
class LogsNotifier extends Notifier<LogsState> {
  @override
  LogsState build() {
    // Loads run after build; state can't be written while it builds.
    Future.microtask(() async {
      await loadLogEntries();
      if (ref.mounted) await _loadCurrentSpecies();
    });
    return const LogsState(isLoading: true);
  }

  List<LogEntry> get logEntries => state.logEntries;
  List<LogBatch> get batches => state.batches;
  double get totalVolume => state.totalVolume;
  bool get isLoading => state.isLoading;
  bool get isBatchesLoading => state.isBatchesLoading;
  String? get error => state.error;
  ConversionFactors get conversionFactors => state.conversionFactors;
  String? get currentSpecies => state.currentSpecies;
  int? get lastAddedId => state.lastAddedId;
  bool get hasEntries => state.hasEntries;
  int get entryCount => state.entryCount;
  double get prmVolume => state.prmVolume;
  double get nmVolume => state.nmVolume;

  /// Load unassigned log entries from database (logs not in any batch)
  Future<void> loadLogEntries() async {
    if (!ref.mounted) return;
    final db = ref.read(databaseServiceProvider);
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Only load logs that are not assigned to a batch
      final entries = await db.getUnassignedLogs();
      final total = await db.getTotalVolume();
      if (!ref.mounted) return;
      state = state.copyWith(
        logEntries: entries,
        totalVolume: total,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Runs [write], then reloads the list. False (with [error] set) when it
  /// failed.
  Future<bool> _write(Future<void> Function() write) async {
    try {
      await write();
      await loadLogEntries();
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Add a new log entry
  /// Parcel assignment is handled automatically by DatabaseService
  Future<bool> addLogEntry(LogEntry entry) => _write(() async {
    final id = await ref.read(databaseServiceProvider).insertLog(entry);
    if (ref.mounted) state = state.copyWith(lastAddedId: id);
  });

  /// Update an existing log entry
  Future<bool> updateLogEntry(LogEntry entry) =>
      _write(() => ref.read(databaseServiceProvider).updateLog(entry));

  /// Delete a log entry
  Future<bool> deleteLogEntry(LogEntry entry) =>
      _write(() => ref.read(databaseServiceProvider).deleteLog(entry.id));

  /// Restore a deleted log entry (undo)
  Future<bool> restoreLogEntry(LogEntry entry) =>
      _write(() => ref.read(databaseServiceProvider).insertLog(entry));

  /// Delete all log entries
  Future<bool> deleteAllLogEntries() =>
      _write(() => ref.read(databaseServiceProvider).deleteAllLogs());

  /// Update conversion factors
  void setConversionFactors(double prm, double nm) {
    state = state.copyWith(
      conversionFactors: ConversionFactors(prm: prm, nm: nm),
    );
  }

  Future<void> _loadCurrentSpecies() async {
    final saved = await ref
        .read(logInputPrefsServiceProvider)
        .getCurrentSpecies();
    if (!ref.mounted) return;
    state = state.copyWith(currentSpecies: saved);
    await ensureValidSpecies();
  }

  /// Keeps a species always selected: the last pick while it still exists,
  /// otherwise the first species in the list (null only when the list is empty).
  Future<void> ensureValidSpecies() async {
    final species = await SpeciesService().getSpecies();
    if (!ref.mounted) return;
    final current = state.currentSpecies;
    if (current != null && species.contains(current)) return;
    await setCurrentSpecies(species.isNotEmpty ? species.first : null);
  }

  /// Set the species that newly added logs get; persisted across restarts.
  Future<void> setCurrentSpecies(String? species) async {
    state = state.copyWith(currentSpecies: species);
    await ref.read(logInputPrefsServiceProvider).saveCurrentSpecies(species);
  }

  /// Export logs to Excel
  Future<bool> exportToExcel() async {
    try {
      await ExportService.exportToExcel(state.logEntries);
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Export logs to JSON
  Future<bool> exportToJson() async {
    try {
      await ExportService.exportToJson(state.logEntries);
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // Batch operations

  /// Load all batches from database
  Future<void> loadBatches() async {
    if (!ref.mounted) return;
    state = state.copyWith(isBatchesLoading: true);

    try {
      final batches = await ref
          .read(databaseServiceProvider)
          .getAllLogBatches();
      if (!ref.mounted) return;
      state = state.copyWith(batches: batches, isBatchesLoading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isBatchesLoading: false, error: e.toString());
    }
  }

  /// Save current logs as a batch and assign all unassigned logs to it
  Future<bool> saveBatch(LogBatch batch) async {
    final db = ref.read(databaseServiceProvider);
    try {
      // Insert the batch and get its ID
      final batchId = await db.insertLogBatch(batch);

      // Assign all current unassigned logs to this batch
      for (final log in state.logEntries) {
        if (log.id != 0 && log.batchId == null) {
          await db.assignLogToBatch(log.id, batchId);
        }
      }

      // Reload both logs and batches
      await loadLogEntries();
      await loadBatches();
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Delete a batch
  Future<bool> deleteBatch(int batchId) async {
    try {
      await ref.read(databaseServiceProvider).deleteLogBatch(batchId);
      // The project's logs return to the working list.
      await Future.wait([loadBatches(), loadLogEntries()]);
      return true;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final logsNotifierProvider = NotifierProvider<LogsNotifier, LogsState>(
  LogsNotifier.new,
);

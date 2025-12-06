import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';
import '../models/log_batch.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

/// State for conversion factors (m³ → PRM/NM)
class ConversionFactors {
  final double prm;
  final double nm;

  const ConversionFactors({this.prm = 0.65, this.nm = 0.40});

  ConversionFactors copyWith({double? prm, double? nm}) {
    return ConversionFactors(prm: prm ?? this.prm, nm: nm ?? this.nm);
  }
}

/// Provider for logs state management
class LogsProvider extends ChangeNotifier {
  final DatabaseService _databaseService;

  LogsProvider({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  // State
  List<LogEntry> _logEntries = [];
  List<LogBatch> _batches = [];
  double _totalVolume = 0.0;
  bool _isLoading = false;
  bool _isBatchesLoading = false;
  String? _error;
  ConversionFactors _conversionFactors = const ConversionFactors();

  // Getters
  List<LogEntry> get logEntries => List.unmodifiable(_logEntries);
  List<LogBatch> get batches => List.unmodifiable(_batches);
  double get totalVolume => _totalVolume;
  bool get isLoading => _isLoading;
  bool get isBatchesLoading => _isBatchesLoading;
  String? get error => _error;
  ConversionFactors get conversionFactors => _conversionFactors;
  bool get hasEntries => _logEntries.isNotEmpty;
  int get entryCount => _logEntries.length;

  // Computed values
  double get prmVolume => _totalVolume * _conversionFactors.prm;
  double get nmVolume => _totalVolume * _conversionFactors.nm;

  /// Load unassigned log entries from database (logs not in any batch)
  Future<void> loadLogEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Only load logs that are not assigned to a batch
      final entries = await _databaseService.getUnassignedLogs();
      final total = await _databaseService.getTotalVolume();

      _logEntries = entries;
      _totalVolume = total;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a new log entry
  /// Parcel assignment is handled automatically by DatabaseService
  Future<bool> addLogEntry(LogEntry entry) async {
    try {
      await _databaseService.insertLog(entry);
      await loadLogEntries();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update an existing log entry
  Future<bool> updateLogEntry(LogEntry entry) async {
    try {
      await _databaseService.updateLog(entry);
      await loadLogEntries();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a log entry
  Future<bool> deleteLogEntry(LogEntry entry) async {
    try {
      await _databaseService.deleteLog(entry.id!);
      await loadLogEntries();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Restore a deleted log entry (undo)
  Future<bool> restoreLogEntry(LogEntry entry) async {
    try {
      await _databaseService.insertLog(entry);
      await loadLogEntries();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete all log entries
  Future<bool> deleteAllLogEntries() async {
    try {
      await _databaseService.deleteAllLogs();
      await loadLogEntries();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update conversion factors
  void setConversionFactors(double prm, double nm) {
    _conversionFactors = ConversionFactors(prm: prm, nm: nm);
    notifyListeners();
  }

  /// Export logs to Excel
  Future<bool> exportToExcel() async {
    try {
      await ExportService.exportToExcel(_logEntries);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Export logs to JSON
  Future<bool> exportToJson() async {
    try {
      await ExportService.exportToJson(_logEntries);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Batch operations

  /// Load all batches from database
  Future<void> loadBatches() async {
    _isBatchesLoading = true;
    notifyListeners();

    try {
      final batches = await _databaseService.getAllLogBatches();
      _batches = batches;
      _isBatchesLoading = false;
      notifyListeners();
    } catch (e) {
      _isBatchesLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Save current logs as a batch and assign all unassigned logs to it
  Future<bool> saveBatch(LogBatch batch) async {
    try {
      // Insert the batch and get its ID
      final batchId = await _databaseService.insertLogBatch(batch);

      // Assign all current unassigned logs to this batch
      for (final log in _logEntries) {
        if (log.id != null && log.batchId == null) {
          await _databaseService.assignLogToBatch(log.id!, batchId);
        }
      }

      // Reload both logs and batches
      await loadLogEntries();
      await loadBatches();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a batch
  Future<bool> deleteBatch(int batchId) async {
    try {
      await _databaseService.deleteLogBatch(batchId);
      await loadBatches();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../widgets/log_card.dart';
import '../widgets/log_entry_form.dart';
import '../widgets/add_log_sheet.dart';
import '../widgets/conversion_settings_sheet.dart';
import '../widgets/save_batch_sheet.dart';
import '../widgets/saved_batches_sheet.dart';

class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  final DatabaseService _databaseService = DatabaseService();

  List<LogEntry> _logEntries = [];
  double _totalVolume = 0.0;
  bool _isLoading = true;

  // Conversion factors (m³ → PRM/NM)
  double _prmFactor = 0.65; // Default: hardwood
  double _nmFactor = 0.40;  // Default: average

  @override
  void initState() {
    super.initState();
    _loadLogEntries();
  }

  void _showConversionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ConversionSettingsSheet(
        totalVolume: _totalVolume,
        prmFactor: _prmFactor,
        nmFactor: _nmFactor,
        onChanged: (prm, nm) {
          setState(() {
            _prmFactor = prm;
            _nmFactor = nm;
          });
        },
      ),
    );
  }

  Future<void> _loadLogEntries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entries = await _databaseService.getAllLogs();
      final total = await _databaseService.getTotalVolume();

      setState(() {
        _logEntries = entries;
        _totalVolume = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri nalaganju vnosov: $e')),
        );
      }
    }
  }

  Future<void> _addLogEntry() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddLogSheet(
        onAdd: (entry) async {
          await _databaseService.insertLog(entry);
          await _loadLogEntries();
        },
      ),
    );
  }

  Future<void> _editLogEntry(LogEntry entry) async {
    final result = await Navigator.of(context).push<LogEntry>(
      MaterialPageRoute(
        builder: (context) => LogEntryForm(logEntry: entry),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      try {
        await _databaseService.updateLog(result);
        await _loadLogEntries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vnos posodobljen')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka pri posodabljanju vnosa: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteLogEntry(LogEntry entry) async {
    try {
      await _databaseService.deleteLog(entry.id!);
      await _loadLogEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vnos izbrisan'),
            action: SnackBarAction(
              label: 'Razveljavi',
              onPressed: () async {
                await _databaseService.insertLog(entry);
                await _loadLogEntries();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri brisanju vnosa: $e')),
        );
      }
    }
  }

  Future<void> _showExportMenu() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izvozi hlode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Izvozi kot Excel'),
              onTap: () => Navigator.of(context).pop('excel'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Izvozi kot JSON'),
              onTap: () => Navigator.of(context).pop('json'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        if (result == 'excel') {
          await ExportService.exportToExcel(_logEntries);
        } else if (result == 'json') {
          await ExportService.exportToJson(_logEntries);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izvoz uspešen')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka pri izvozu: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAllLogs() async {
    if (_logEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ni vnosov za brisanje')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odstrani vse hlode'),
        content: Text(
          'Ali ste prepričani, da želite odstraniti vseh ${_logEntries.length} vnosov?\n\n'
          'Skupni volumen: ${_totalVolume.toStringAsFixed(2)} m³\n\n'
          'To dejanje ni mogoče razveljaviti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Odstrani vse'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _databaseService.deleteAllLogs();
        await _loadLogEntries();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vsi vnosi odstranjeni')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka pri brisanju: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveBatch() async {
    if (_logEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ni vnosov za shranjevanje')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SaveBatchSheet(
        totalVolume: _totalVolume,
        logCount: _logEntries.length,
        onSave: (batch) async {
          await _databaseService.insertLogBatch(batch);
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Shranjeno')),
            );
          }
        },
      ),
    );
  }

  Future<void> _showSavedBatches() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SavedBatchesSheet(
        databaseService: _databaseService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hlodi'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'save') {
                _saveBatch();
              } else if (value == 'saved') {
                _showSavedBatches();
              } else if (value == 'export') {
                _showExportMenu();
              } else if (value == 'delete_all') {
                _deleteAllLogs();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save',
                enabled: _logEntries.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.save),
                    SizedBox(width: 8),
                    Text('Shrani'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'saved',
                child: Row(
                  children: [
                    Icon(Icons.folder),
                    SizedBox(width: 8),
                    Text('Shranjeno'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Izvozi'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Odstrani vse'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLogEntries,
              child: Column(
                children: [
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: InkWell(
                      onTap: _showConversionDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_totalVolume.toStringAsFixed(2)} m³',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[400],
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_totalVolume * _prmFactor).toStringAsFixed(2)} PRM  •  ${(_totalVolume * _nmFactor).toStringAsFixed(2)} NM',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[500],
                                      ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              '${_logEntries.length} hlodov',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _logEntries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.forest_outlined,
                                  size: 64,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Ni še hlodov',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.grey[500],
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tapnite + za dodajanje hloda',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _logEntries.length,
                            itemBuilder: (context, index) {
                              final entry = _logEntries[index];
                              return LogCard(
                                logEntry: entry,
                                onTap: () => _editLogEntry(entry),
                                onDismissed: () => _deleteLogEntry(entry),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'logs_add',
        onPressed: _addLogEntry,
        child: const Icon(Icons.add),
      ),
    );
  }
}

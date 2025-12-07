import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/log_batch.dart';
import '../models/log_entry.dart';
import '../providers/logs_provider.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../widgets/conversion_settings_sheet.dart';
import '../widgets/log_card.dart';

class BatchDetailScreen extends StatefulWidget {
  final LogBatch batch;

  const BatchDetailScreen({super.key, required this.batch});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late LogBatch _batch;
  List<LogEntry> _logs = [];
  double _totalVolume = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _databaseService.getLogsByBatch(_batch.id);
      double total = 0;
      for (final log in logs) {
        total += log.volume;
      }

      // Update batch totals in database if changed
      if (_batch.totalVolume != total || _batch.logCount != logs.length) {
        final updatedBatch = _batch.copyWith(
          totalVolume: total,
          logCount: logs.length,
        );
        await _databaseService.updateLogBatch(updatedBatch);
        _batch = updatedBatch;
      }

      setState(() {
        _logs = logs;
        _totalVolume = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')),
        );
      }
    }
  }

  Future<void> _addLog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddLogToBatchSheet(
        batchId: _batch.id,
        onAdd: (entry) async {
          await _databaseService.insertLog(entry);
          await _loadLogs();
        },
      ),
    );
  }

  Future<void> _editBatchInfo() async {
    final result = await showModalBottomSheet<LogBatch>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditBatchInfoSheet(batch: _batch),
    );

    if (result != null) {
      await _databaseService.updateLogBatch(result);
      setState(() => _batch = result);
    }
  }

  Future<void> _deleteLog(LogEntry entry) async {
    try {
      await _databaseService.deleteLog(entry.id);
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hlod izbrisan'),
            action: SnackBarAction(
              label: 'Razveljavi',
              onPressed: () async {
                final newEntry = LogEntry(
                  diameter: entry.diameter,
                  length: entry.length,
                  volume: entry.volume,
                  latitude: entry.latitude,
                  longitude: entry.longitude,
                  notes: entry.notes,
                  batchId: _batch.id,
                );
                await _databaseService.insertLog(newEntry);
                await _loadLogs();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')),
        );
      }
    }
  }

  Future<void> _deleteBatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izbriši projekt'),
        content: Text(
          'Ali ste prepričani, da želite izbrisati "${_batch.owner ?? 'ta projekt'}"?\n\n'
          'Hlodi (${_logs.length}) bodo ostali, vendar ne bodo več dodeljeni projektu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Izbriši'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.deleteLogBatch(_batch.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _showConversionDialog() {
    final provider = context.read<LogsProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ConversionSettingsSheet(
        totalVolume: _totalVolume,
        prmFactor: provider.conversionFactors.prm,
        nmFactor: provider.conversionFactors.nm,
        onChanged: (prm, nm) {
          provider.setConversionFactors(prm, nm);
          setState(() {}); // Refresh to show updated conversions
        },
      ),
    );
  }

  Future<void> _showExportMenu() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ni hlodov za izvoz')),
      );
      return;
    }

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
          await ExportService.exportToExcel(_logs);
        } else {
          await ExportService.exportToJson(_logs);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izvoz uspešen')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. M. yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_batch.owner ?? 'Projekt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Izvozi',
            onPressed: _showExportMenu,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Uredi info',
            onPressed: _editBatchInfo,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Izbriši',
            onPressed: _deleteBatch,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<LogsProvider>(
              builder: (context, provider, _) {
                final prmVolume = _totalVolume * provider.conversionFactors.prm;
                final nmVolume = _totalVolume * provider.conversionFactors.nm;
                return Column(
                  children: [
                    // Summary card (tap for conversion dialog)
                    Card(
                      margin: const EdgeInsets.all(12),
                      child: InkWell(
                        onTap: _showConversionDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: [
                              Row(
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
                                        '${prmVolume.toStringAsFixed(2)} PRM  •  ${nmVolume.toStringAsFixed(2)} NM',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[500],
                                            ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_logs.length} hlodov',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey[500],
                                        ),
                                  ),
                                ],
                              ),
                              if (_batch.notes != null && _batch.notes!.isNotEmpty) ...[
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _batch.notes!,
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateFormat.format(_batch.createdAt),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                  if (_batch.hasLocation) ...[
                                    const SizedBox(width: 16),
                                    Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_batch.latitude!.toStringAsFixed(4)}, ${_batch.longitude!.toStringAsFixed(4)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Logs list
                    Expanded(
                      child: _logs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.forest_outlined, size: 64, color: Colors.grey[600]),
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
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final entry = _logs[index];
                                return LogCard(
                                  logEntry: entry,
                                  onTap: () {}, // View-only in batch
                                  onDismissed: () => _deleteLog(entry),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'batch_add_log',
        onPressed: _addLog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddLogToBatchSheet extends StatefulWidget {
  final int batchId;
  final Future<void> Function(LogEntry entry) onAdd;

  const _AddLogToBatchSheet({required this.batchId, required this.onAdd});

  @override
  State<_AddLogToBatchSheet> createState() => _AddLogToBatchSheetState();
}

class _AddLogToBatchSheetState extends State<_AddLogToBatchSheet> {
  final _formKey = GlobalKey<FormState>();
  final _diameterController = TextEditingController();
  final _lengthController = TextEditingController();
  final _diameterFocus = FocusNode();

  double? _calculatedVolume;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isSaving = false;
  int _addedCount = 0;

  @override
  void initState() {
    super.initState();
    _diameterController.addListener(_updateVolume);
    _lengthController.addListener(_updateVolume);
  }

  @override
  void dispose() {
    _diameterController.dispose();
    _lengthController.dispose();
    _diameterFocus.dispose();
    super.dispose();
  }

  void _updateVolume() {
    final diameter = double.tryParse(_diameterController.text);
    final length = double.tryParse(_lengthController.text);

    setState(() {
      if (diameter != null && length != null && diameter > 0 && length > 0) {
        _calculatedVolume = LogEntry.calculateVolume(diameter, length);
      } else {
        _calculatedVolume = null;
      }
    });
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  LogEntry? _createEntry() {
    if (!_formKey.currentState!.validate() || _calculatedVolume == null) {
      return null;
    }

    return LogEntry(
      diameter: double.parse(_diameterController.text),
      length: double.parse(_lengthController.text),
      volume: _calculatedVolume!,
      latitude: _latitude,
      longitude: _longitude,
      batchId: widget.batchId,
    );
  }

  Future<void> _saveAndContinue() async {
    final entry = _createEntry();
    if (entry == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.onAdd(entry);
      setState(() {
        _addedCount++;
        _diameterController.clear();
        _lengthController.clear();
        _calculatedVolume = null;
      });
      _diameterFocus.requestFocus();
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    _addedCount > 0 ? 'Dodaj hlod (+$_addedCount)' : 'Dodaj hlod',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _diameterController,
                      focusNode: _diameterFocus,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Premer (cm)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (v) => v == null || v.isEmpty ? 'Vnesi' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lengthController,
                      decoration: const InputDecoration(
                        labelText: 'Dolžina (m)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (v) => v == null || v.isEmpty ? 'Vnesi' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_calculatedVolume != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Volumen: ${_calculatedVolume!.toStringAsFixed(4)} m³',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_latitude != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() {
                              _latitude = null;
                              _longitude = null;
                            }),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: _isLoadingLocation ? null : _getLocation,
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 16),
                      label: const Text('Lokacija'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _calculatedVolume != null && !_isSaving ? _saveAndContinue : null,
                    child: const Text('Dodaj'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditBatchInfoSheet extends StatefulWidget {
  final LogBatch batch;

  const _EditBatchInfoSheet({required this.batch});

  @override
  State<_EditBatchInfoSheet> createState() => _EditBatchInfoSheetState();
}

class _EditBatchInfoSheetState extends State<_EditBatchInfoSheet> {
  final _ownerController = TextEditingController();
  final _notesController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _ownerController.text = widget.batch.owner ?? '';
    _notesController.text = widget.batch.notes ?? '';
    _latitude = widget.batch.latitude;
    _longitude = widget.batch.longitude;
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _save() {
    final updated = widget.batch.copyWith(
      owner: _ownerController.text.isEmpty ? null : _ownerController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      latitude: _latitude,
      longitude: _longitude,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Uredi projekt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _ownerController,
              decoration: const InputDecoration(
                labelText: 'Lastnik',
                hintText: 'Ime lastnika',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Opombe',
                hintText: 'Dodatne opombe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                if (_latitude != null)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() {
                            _latitude = null;
                            _longitude = null;
                          }),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _isLoadingLocation ? null : _getLocation,
                    icon: _isLoadingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 16),
                    label: const Text('Dodaj lokacijo'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Shrani'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

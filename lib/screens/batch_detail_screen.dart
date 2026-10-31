import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/log_batch.dart';
import '../models/log_entry.dart';
import '../providers/logs_provider.dart';
import '../providers/map_provider.dart';
import '../router/app_router.dart';
import '../router/route_names.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/location_settings.dart';
import '../services/species_service.dart';
import '../utils/decimal_input.dart';
import '../utils/formats.dart';
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
          SnackBar(content: Text(context.l10n.logsErrorWithDetail('$e'))),
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

  /// Correct a saved log with the same full-screen form as the Hlodi tab.
  void _editLog(LogEntry entry) {
    final mapProvider = context.read<MapProvider>();
    final hadLocation = entry.hasLocation;
    context.push(
      AppRoutes.logEdit(entry.id),
      extra: LogEntryFormParams(
        logEntry: entry,
        onSave: (result) async {
          try {
            // Keep it in this batch whatever the form returns.
            await _databaseService.updateLog(
              result.copyWith(batchId: _batch.id),
            );
            await _loadLogs();
            if (hadLocation || result.hasLocation) {
              mapProvider.loadGeolocatedLogs();
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.logsEntryUpdated)),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.logsErrorWithDetail('$e'))),
              );
            }
          }
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
            content: Text(context.l10n.batchLogDeleted),
            action: SnackBarAction(
              label: context.l10n.logsUndo,
              onPressed: () async {
                final newEntry = LogEntry(
                  diameter: entry.diameter,
                  length: entry.length,
                  volume: entry.volume,
                  latitude: entry.latitude,
                  longitude: entry.longitude,
                  notes: entry.notes,
                  species: entry.species,
                  createdAt: entry.createdAt,
                  parcelId: entry.parcelId,
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
          SnackBar(content: Text(context.l10n.logsErrorWithDetail('$e'))),
        );
      }
    }
  }

  Future<void> _deleteBatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logsSavedDeleteTitle),
        content: Text(
          context.l10n.batchDeleteConfirm(
            _batch.name ?? context.l10n.batchDeleteFallbackName,
            _logs.length,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<LogsProvider>().deleteBatch(_batch.id);
      if (mounted) {
        context.pop();
      }
    }
  }

  void _showConversionDialog() {
    final provider = context.read<LogsProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConversionSettingsSheet(
          totalVolume: _totalVolume,
          prmFactor: provider.conversionFactors.prm,
          nmFactor: provider.conversionFactors.nm,
          onChanged: (prm, nm) {
            provider.setConversionFactors(prm, nm);
            setState(() {}); // Refresh to show updated conversions
          },
        ),
      ),
    );
  }

  Future<void> _showExportMenu() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.batchNoLogsToExport)),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logsExportTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: Text(context.l10n.logsExportExcel),
              onTap: () => Navigator.of(context).pop('excel'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(context.l10n.logsExportJson),
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
            SnackBar(content: Text(context.l10n.logsExportSuccess)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.logsErrorWithDetail('$e'))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_batch.name ?? context.l10n.batchDefaultTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: context.l10n.logsMenuExport,
            onPressed: _showExportMenu,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.batchEditInfoTooltip,
            onPressed: _editBatchInfo,
          ),
          // Delete lives in the overflow menu, away from Edit (still confirms).
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: context.l10n.logsMoreOptionsTooltip,
            onSelected: (value) {
              if (value == 'delete') _deleteBatch();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(context.l10n.commonDelete),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<LogsProvider>(
              builder: (context, provider, _) {
                final prmVolume = provider.conversionFactors.toPrm(_totalVolume);
                final nmVolume = provider.conversionFactors.toNm(_totalVolume);
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        Fmt.m3(_totalVolume),
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[400],
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${Fmt.num(prmVolume, 2)} PRM  •  ${Fmt.num(nmVolume, 2)} NM',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[500],
                                            ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    context.l10n.logsCountLogs(_logs.length),
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
                                    Icon(Icons.note, size: 16, color: Colors.grey[400]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _batch.notes!,
                                        style: TextStyle(color: Colors.grey[400]),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    Fmt.dateTime(_batch.createdAt),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                  if (_batch.hasLocation) ...[
                                    const SizedBox(width: 16),
                                    Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${_batch.latitude!.toStringAsFixed(4)}, ${_batch.longitude!.toStringAsFixed(4)}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                                  Icon(Icons.forest_outlined, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    context.l10n.logsEmptyTitle,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: Colors.grey[500],
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.l10n.batchEmptyHint,
                                    style: TextStyle(color: Colors.grey[400]),
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
                                  onTap: () => _editLog(entry),
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

  final _speciesService = SpeciesService();
  List<String> _availableSpecies = [];
  String? _selectedSpecies;

  @override
  void initState() {
    super.initState();
    _loadSpecies();
    _diameterController.addListener(_updateVolume);
    _lengthController.addListener(_updateVolume);
  }

  Future<void> _loadSpecies() async {
    final species = await _speciesService.getSpecies();
    if (!mounted) return;
    setState(() {
      _availableSpecies = species;
    });
  }

  @override
  void dispose() {
    _diameterController.dispose();
    _lengthController.dispose();
    _diameterFocus.dispose();
    super.dispose();
  }

  void _updateVolume() {
    final diameter = parseDecimal(_diameterController.text);
    final length = parseDecimal(_lengthController.text);

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
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.logsLocationPermissionDenied)),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: GozdarLocationSettings.currentPosition,
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.logsErrorWithDetail('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  LogEntry? _createEntry() {
    if (!_formKey.currentState!.validate() || _calculatedVolume == null) {
      return null;
    }

    return LogEntry(
      diameter: parseDecimal(_diameterController.text),
      length: parseDecimal(_lengthController.text),
      volume: _calculatedVolume!,
      latitude: _latitude,
      longitude: _longitude,
      species: _selectedSpecies,
      batchId: widget.batchId,
    );
  }

  Future<void> _saveAndContinue() async {
    final entry = _createEntry();
    if (entry == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.onAdd(entry);
      if (!mounted) return;
      setState(() {
        _addedCount++;
        _diameterController.clear();
        _lengthController.clear();
        _calculatedVolume = null;
      });
      if (mounted) {
        _diameterFocus.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
                    _addedCount > 0
                        ? context.l10n.batchAddTitleCount(_addedCount)
                        : context.l10n.commonAdd,
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
                      decoration: InputDecoration(
                        labelText: context.l10n.logsDiameterLabel,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        DecimalTextInputFormatter(),
                      ],
                      validator: (v) => v == null || v.isEmpty ? context.l10n.batchValidatorEnter : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lengthController,
                      decoration: InputDecoration(
                        labelText: context.l10n.logsLengthLabel,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        DecimalTextInputFormatter(),
                      ],
                      validator: (v) => v == null || v.isEmpty ? context.l10n.batchValidatorEnter : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedSpecies,
                decoration: InputDecoration(
                  labelText: context.l10n.logsSpeciesLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.forest, size: 18),
                  suffixIcon: _selectedSpecies != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedSpecies = null;
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(context.l10n.logsNotSelected),
                  ),
                  ..._availableSpecies.map((species) {
                    return DropdownMenuItem<String>(
                      value: species,
                      child: Text(species),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSpecies = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_calculatedVolume != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.green[300]),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.batchVolumeLine(Fmt.num(_calculatedVolume!, 2)),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[200],
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
                          Icon(Icons.location_on, size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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
                      label: Text(context.l10n.logsLocationLabel),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _calculatedVolume != null && !_isSaving ? _saveAndContinue : null,
                    child: Text(context.l10n.commonAdd),
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
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.batch.name ?? '';
    _notesController.text = widget.batch.notes ?? '';
    _latitude = widget.batch.latitude;
    _longitude = widget.batch.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: GozdarLocationSettings.currentPosition,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.logsErrorWithDetail('$e'))),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _save() {
    final updated = widget.batch.copyWith(
      name: _nameController.text.isEmpty ? null : _nameController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      latitude: _latitude,
      longitude: _longitude,
      clearName: _nameController.text.isEmpty,
      clearNotes: _notesController.text.isEmpty,
      clearLocation: _latitude == null || _longitude == null,
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
                Text(
                  context.l10n.commonEdit,
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
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.logsNameLabel,
                hintText: context.l10n.logsNameHint,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: context.l10n.logsNotesLabel,
                hintText: context.l10n.batchNotesHint,
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
                        Icon(Icons.location_on, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
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
                    label: Text(context.l10n.logsAddLocation),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  child: Text(context.l10n.commonSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

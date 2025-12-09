import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/log_entry.dart';
import '../providers/logs_provider.dart';
import '../providers/map_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/log_card.dart';
import '../widgets/log_entry_form.dart';
import '../widgets/add_log_sheet.dart';
import '../widgets/conversion_settings_sheet.dart';
import '../widgets/save_batch_sheet.dart';
import '../widgets/saved_batches_sheet.dart';
import '../widgets/species_management_sheet.dart';

class LogsTab extends StatelessWidget {
  const LogsTab({super.key});

  void _showConversionDialog(BuildContext context) {
    final provider = context.read<LogsProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ConversionSettingsSheet(
        totalVolume: provider.totalVolume,
        prmFactor: provider.conversionFactors.prm,
        nmFactor: provider.conversionFactors.nm,
        onChanged: (prm, nm) {
          provider.setConversionFactors(prm, nm);
          AnalyticsService().logConversionSettingsChanged();
        },
      ),
    );
  }

  Future<void> _addLogEntry(BuildContext context) async {
    final provider = context.read<LogsProvider>();
    final mapProvider = context.read<MapProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddLogSheet(
        onAdd: (entry) async {
          await provider.addLogEntry(entry);
          AnalyticsService().logLogAdded(
            volumeM3: entry.volume,
            hasLocation: entry.hasLocation,
          );
          // Refresh map markers if log has location
          if (entry.hasLocation) {
            mapProvider.loadGeolocatedLogs();
          }
        },
      ),
    );
  }

  Future<void> _editLogEntry(BuildContext context, LogEntry entry) async {
    final provider = context.read<LogsProvider>();
    final mapProvider = context.read<MapProvider>();
    final hadLocation = entry.hasLocation;
    final result = await Navigator.of(context).push<LogEntry>(
      MaterialPageRoute(
        builder: (context) => LogEntryForm(logEntry: entry),
        fullscreenDialog: true,
      ),
    );

    if (result != null && context.mounted) {
      final success = await provider.updateLogEntry(result);
      if (success && context.mounted) {
        AnalyticsService().logLogEdited();
        // Refresh map markers if location changed
        if (hadLocation || result.hasLocation) {
          mapProvider.loadGeolocatedLogs();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vnos posodobljen')),
        );
      } else if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka: ${provider.error}')),
        );
      }
    }
  }

  Future<void> _deleteLogEntry(BuildContext context, LogEntry entry) async {
    final provider = context.read<LogsProvider>();
    final mapProvider = context.read<MapProvider>();
    final success = await provider.deleteLogEntry(entry);

    if (success && context.mounted) {
      AnalyticsService().logLogDeleted();
      // Refresh map markers if log had location
      if (entry.hasLocation) {
        mapProvider.loadGeolocatedLogs();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vnos izbrisan'),
          action: SnackBarAction(
            label: 'Razveljavi',
            onPressed: () async {
              await provider.restoreLogEntry(entry);
              // Refresh map markers if log had location
              if (entry.hasLocation) {
                mapProvider.loadGeolocatedLogs();
              }
            },
          ),
        ),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Napaka: ${provider.error}')),
      );
    }
  }

  Future<void> _showExportMenu(BuildContext context) async {
    final provider = context.read<LogsProvider>();
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

    if (result != null && context.mounted) {
      bool success;
      if (result == 'excel') {
        success = await provider.exportToExcel();
      } else {
        success = await provider.exportToJson();
      }

      if (context.mounted) {
        if (success) {
          AnalyticsService().logLogsExported(
            format: result,
            count: provider.entryCount,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izvoz uspešen')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka: ${provider.error}')),
          );
        }
      }
    }
  }

  Future<void> _deleteAllLogs(BuildContext context) async {
    final provider = context.read<LogsProvider>();

    if (!provider.hasEntries) {
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
          'Ali ste prepričani, da želite odstraniti vseh ${provider.entryCount} vnosov?\n\n'
          'Skupni volumen: ${provider.totalVolume.toStringAsFixed(2)} m³\n\n'
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

    if (confirmed == true && context.mounted) {
      final count = provider.entryCount;
      final success = await provider.deleteAllLogEntries();
      if (context.mounted) {
        if (success) {
          AnalyticsService().logLogsAllDeleted(count: count);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vsi vnosi odstranjeni')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka: ${provider.error}')),
          );
        }
      }
    }
  }

  Future<void> _saveBatch(BuildContext context) async {
    final provider = context.read<LogsProvider>();

    if (!provider.hasEntries) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ni vnosov za shranjevanje')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SaveBatchSheet(
        totalVolume: provider.totalVolume,
        logCount: provider.entryCount,
        onSave: (batch) async {
          final success = await provider.saveBatch(batch);
          if (context.mounted) {
            if (success) {
              AnalyticsService().logBatchSaved(
                logCount: provider.entryCount,
                totalVolume: provider.totalVolume,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Shranjeno')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _showSavedBatches(BuildContext context) async {
    AnalyticsService().logBatchViewed();
    await SavedBatchesSheet.show(context);
  }

  Future<void> _showSpeciesManagement(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SpeciesManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hlodi'),
        actions: [
          Consumer<LogsProvider>(
            builder: (context, provider, _) => IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Shrani',
              onPressed: provider.hasEntries ? () => _saveBatch(context) : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Shranjeno',
            onPressed: () => _showSavedBatches(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _showExportMenu(context);
              } else if (value == 'delete_all') {
                _deleteAllLogs(context);
              } else if (value == 'manage_species') {
                _showSpeciesManagement(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manage_species',
                child: Row(
                  children: [
                    Icon(Icons.forest, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Upravljanje vrst'),
                  ],
                ),
              ),
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
      body: Consumer<LogsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadLogEntries(),
            child: Column(
              children: [
                // Volume summary card
                Card(
                  margin: const EdgeInsets.all(12),
                  child: InkWell(
                    onTap: () => _showConversionDialog(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${provider.totalVolume.toStringAsFixed(2)} m³',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[400],
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${provider.prmVolume.toStringAsFixed(2)} PRM  •  ${provider.nmVolume.toStringAsFixed(2)} NM',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '${provider.entryCount} hlodov',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Log entries list
                Expanded(
                  child: provider.logEntries.isEmpty
                      ? _buildEmptyState(context)
                      : _buildGroupedLogsList(context, provider),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'logs_add',
        onPressed: () => _addLogEntry(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGroupedLogsList(BuildContext context, LogsProvider provider) {
    // Group logs by species
    final groupedLogs = <String, List<LogEntry>>{};
    for (final entry in provider.logEntries) {
      final species = entry.species ?? 'Neznana vrsta';
      if (!groupedLogs.containsKey(species)) {
        groupedLogs[species] = [];
      }
      groupedLogs[species]!.add(entry);
    }

    // Progressive enhancement: only show grouping if more than one species
    if (groupedLogs.length <= 1) {
      return ListView.builder(
        itemCount: provider.logEntries.length,
        itemBuilder: (context, index) {
          final entry = provider.logEntries[index];
          return LogCard(
            logEntry: entry,
            onTap: () => _editLogEntry(context, entry),
            onDismissed: () => _deleteLogEntry(context, entry),
          );
        },
      );
    }

    // Sort species alphabetically, but put "Neznana vrsta" at the end
    final sortedSpecies = groupedLogs.keys.toList()
      ..sort((a, b) {
        if (a == 'Neznana vrsta') return 1;
        if (b == 'Neznana vrsta') return -1;
        return a.compareTo(b);
      });

    return ListView.builder(
      itemCount: sortedSpecies.length,
      itemBuilder: (context, groupIndex) {
        final species = sortedSpecies[groupIndex];
        final entries = groupedLogs[species]!;
        final count = entries.length;
        final totalVolume = entries.fold<double>(0, (sum, entry) => sum + entry.volume);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Species header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Icon(
                    Icons.forest,
                    size: 20,
                    color: Colors.green[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    species,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '$count hlodov • ${totalVolume.toStringAsFixed(2)} m³',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            // Logs in this group
            ...entries.map((entry) {
              return LogCard(
                logEntry: entry,
                onTap: () => _editLogEntry(context, entry),
                onDismissed: () => _deleteLogEntry(context, entry),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.forest_outlined,
                size: 48,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}

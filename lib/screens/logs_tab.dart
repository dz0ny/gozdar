import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/log_entry.dart';
import '../providers/logs_provider.dart';
import '../providers/map_provider.dart';
import '../router/app_router.dart';
import '../router/route_names.dart';
import '../services/species_service.dart';
import '../widgets/log_card.dart';
import '../widgets/inline_add_log.dart';
import '../widgets/conversion_settings_sheet.dart';
import '../widgets/save_batch_sheet.dart';
import '../widgets/saved_batches_sheet.dart';
import '../widgets/species_management_sheet.dart';

class LogsTab extends StatelessWidget {
  const LogsTab({super.key});

  Future<void> _showConversionDialog(BuildContext context) async {
    final provider = context.read<LogsProvider>();
    final species = await SpeciesService().getSpecies();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
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
          totalVolume: provider.totalVolume,
          prmFactor: provider.conversionFactors.prm,
          nmFactor: provider.conversionFactors.nm,
          onChanged: (prm, nm) {
            provider.setConversionFactors(prm, nm);
          },
          availableSpecies: species,
          selectedSpecies: provider.currentSpecies,
          onSpeciesChanged: provider.setCurrentSpecies,
        ),
      ),
    );
  }

  /// Inline quick-add bar pinned under the list (no popup).
  Widget _buildInlineAdd(BuildContext context) {
    final provider = context.read<LogsProvider>();
    final mapProvider = context.read<MapProvider>();
    return InlineAddLog(
      species: provider.currentSpecies,
      onAdd: (entry) async {
        await provider.addLogEntry(entry);
        // Refresh map markers if log has location
        if (entry.hasLocation) {
          mapProvider.loadGeolocatedLogs();
        }
      },
    );
  }

  void _editLogEntry(BuildContext context, LogEntry entry) {
    final provider = context.read<LogsProvider>();
    final mapProvider = context.read<MapProvider>();
    final hadLocation = entry.hasLocation;

    context.push(
      AppRoutes.logEdit(entry.id),
      extra: LogEntryFormParams(
        logEntry: entry,
        onSave: (result) async {
          final success = await provider.updateLogEntry(result);
          if (success && context.mounted) {
            // Refresh map markers if location changed
            if (hadLocation || result.hasLocation) {
              mapProvider.loadGeolocatedLogs();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.logsEntryUpdated)),
            );
          } else if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.logsErrorWithDetail('${provider.error}'))),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteLogEntry(BuildContext context, LogEntry entry) async {
    final provider = context.read<LogsProvider>();
    final mapProvider = context.read<MapProvider>();
    final success = await provider.deleteLogEntry(entry);

    if (success && context.mounted) {
      // Refresh map markers if log had location
      if (entry.hasLocation) {
        mapProvider.loadGeolocatedLogs();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.logsEntryDeleted),
          action: SnackBarAction(
            label: context.l10n.logsUndo,
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
        SnackBar(content: Text(context.l10n.logsErrorWithDetail('${provider.error}'))),
      );
    }
  }

  Future<void> _showExportMenu(BuildContext context) async {
    final provider = context.read<LogsProvider>();
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

    if (result != null && context.mounted) {
      bool success;
      if (result == 'excel') {
        success = await provider.exportToExcel();
      } else {
        success = await provider.exportToJson();
      }

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.logsExportSuccess)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.logsErrorWithDetail('${provider.error}'))),
          );
        }
      }
    }
  }

  Future<void> _deleteAllLogs(BuildContext context) async {
    final provider = context.read<LogsProvider>();

    if (!provider.hasEntries) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.logsNoEntriesToDelete)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logsDeleteAllTitle),
        content: Text(
          context.l10n.logsDeleteAllConfirm(
            provider.entryCount,
            provider.totalVolume.toStringAsFixed(2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(context.l10n.logsMenuDeleteAll),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await provider.deleteAllLogEntries();
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.logsAllEntriesRemoved)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.logsErrorWithDetail('${provider.error}'))),
          );
        }
      }
    }
  }

  Future<void> _saveBatch(BuildContext context) async {
    final provider = context.read<LogsProvider>();

    if (!provider.hasEntries) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.logsNoEntriesToSave)),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.logsSaved)),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.logsSaveError)),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _showSavedBatches(BuildContext context) async {
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
        title: Text(context.l10n.logsHeaderTitle),
        actions: [
          Consumer<LogsProvider>(
            builder: (context, provider, _) => IconButton(
              icon: const Icon(Icons.save),
              tooltip: context.l10n.commonSave,
              onPressed: provider.hasEntries ? () => _saveBatch(context) : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: context.l10n.logsSavedTooltip,
            onPressed: () => _showSavedBatches(context),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.logsMoreOptionsTooltip,
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
              PopupMenuItem(
                value: 'manage_species',
                child: Row(
                  children: [
                    const Icon(Icons.forest, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(context.l10n.logsMenuManageSpecies),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.file_download),
                    const SizedBox(width: 8),
                    Text(context.l10n.logsMenuExport),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(context.l10n.logsMenuDeleteAll),
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
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[400],
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${provider.prmVolume.toStringAsFixed(2)} PRM  •  ${provider.nmVolume.toStringAsFixed(2)} NM',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                context.l10n.logsCountLogs(provider.entryCount),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.forest, size: 18, color: Colors.green[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    provider.currentSpecies ?? context.l10n.logsSpeciesNotSelected,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Colors.grey[500],
                                        ),
                                  ),
                                ],
                              ),
                            ],
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

                // Quick-add bar (always visible, no popup)
                _buildInlineAdd(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupedLogsList(BuildContext context, LogsProvider provider) {
    // Group logs by species
    final unknownSpecies = context.l10n.logsUnknownSpecies;
    final groupedLogs = <String, List<LogEntry>>{};
    for (final entry in provider.logEntries) {
      final species = entry.species ?? unknownSpecies;
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
        if (a == unknownSpecies) return 1;
        if (b == unknownSpecies) return -1;
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(
                    Icons.forest,
                    size: 20,
                    color: Colors.green[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    species,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    context.l10n.logsGroupSummary(count, totalVolume.toStringAsFixed(2)),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      physics: const AlwaysScrollableScrollPhysics(),
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
                context.l10n.logsEmptyTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.logsEmptyHint,
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

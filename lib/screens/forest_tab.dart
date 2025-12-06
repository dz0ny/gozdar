import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/parcel.dart';
import '../services/database_service.dart';
import '../services/kml_service.dart';
import '../widgets/parcel_silhouette.dart';
import 'parcel_editor.dart';
import 'parcel_detail_screen.dart';

/// Get icon and color for forest type
(IconData, Color) getForestTypeIcon(ForestType type) {
  switch (type) {
    case ForestType.deciduous:
      return (Icons.nature, Colors.green.shade600); // Listavci - broadleaf
    case ForestType.coniferous:
      return (Icons.park, Colors.green.shade800); // Iglavci - conifer
    case ForestType.mixed:
      return (Icons.forest, Colors.green.shade400); // Mešani
  }
}

class ForestTab extends StatefulWidget {
  const ForestTab({super.key});

  @override
  State<ForestTab> createState() => ForestTabState();
}

class ForestTabState extends State<ForestTab> {
  final DatabaseService _databaseService = DatabaseService();

  /// Public method to refresh data from outside
  Future<void> refresh() => _loadData();

  List<Parcel> _parcels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final parcels = await _databaseService.getAllParcels();

      setState(() {
        _parcels = parcels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri nalaganju: $e')),
        );
      }
    }
  }

  Future<void> _addParcel() async {
    final result = await Navigator.of(context).push<Parcel>(
      MaterialPageRoute(
        builder: (context) => const ParcelEditor(),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      try {
        await _databaseService.insertParcel(result);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parcela dodana')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Napaka pri dodajanju: $e')),
          );
        }
      }
    }
  }

  Future<void> _openParcelDetail(Parcel parcel) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ParcelDetailScreen(parcel: parcel),
      ),
    );

    // Refresh if parcel was deleted or modified
    if (result == true || mounted) {
      await _loadData();
    }
  }

  Future<void> _deleteParcel(Parcel parcel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izbriši parcelo'),
        content: Text('Ali ste prepričani, da želite izbrisati "${parcel.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Izbriši'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseService.deleteParcel(parcel.id!);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Parcela izbrisana'),
              action: SnackBarAction(
                label: 'Razveljavi',
                onPressed: () async {
                  await _databaseService.insertParcel(parcel);
                  await _loadData();
                },
              ),
            ),
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

  Future<void> _exportKml() async {
    if (_parcels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ni parcel za izvoz')),
      );
      return;
    }

    try {
      await KmlService.exportToKml(_parcels);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KML uspešno izvožen')),
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

  Future<void> _importKml() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kml', 'kmz'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final content = await file.readAsString();

      final parcels = KmlService.importFromKml(content);

      if (parcels.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('V datoteki ni veljavnih parcel')),
          );
        }
        return;
      }

      // Ask user to confirm import
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Uvozi parcele'),
          content: Text('Najdenih ${parcels.length} parcel. Jih uvozim?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Prekliči'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Uvozi'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        for (final parcel in parcels) {
          await _databaseService.insertParcel(parcel);
        }
        await _loadData();
        if (mounted) {
          final totalArea = parcels.fold(0.0, (double sum, p) => sum + p.areaM2);
          final areaFormatted = totalArea >= 10000
              ? '${(totalArea / 10000).toStringAsFixed(2)} ha'
              : '${totalArea.toStringAsFixed(0)} m²';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uvoženih ${parcels.length} parcel ($areaFormatted)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Napaka pri uvozu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate totals from parcel data
    final totalArea = _parcels.fold(0.0, (double sum, p) => sum + p.areaM2);
    final totalAreaFormatted = totalArea >= 10000
        ? '${(totalArea / 10000).toStringAsFixed(2)} ha'
        : '${totalArea.toStringAsFixed(0)} m²';

    // Sum up wood cut and trees from all parcels
    int totalTrees = 0;
    double totalVolume = 0.0;
    for (final parcel in _parcels) {
      totalTrees += parcel.treesCut;
      totalVolume += parcel.woodCut;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moj Gozd'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'import') {
                _importKml();
              } else if (value == 'export') {
                _exportKml();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload),
                    SizedBox(width: 8),
                    Text('Uvozi KML'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Izvozi KML'),
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
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Summary card - compact
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _SummaryItem(
                            icon: Icons.park,
                            value: totalAreaFormatted,
                            label: 'Površina',
                          ),
                          _SummaryItem(
                            icon: Icons.grid_view,
                            value: '${_parcels.length}',
                            label: 'Parcel',
                          ),
                          _SummaryItem(
                            icon: Icons.nature,
                            value: '$totalTrees',
                            label: 'Dreves',
                          ),
                          _SummaryItem(
                            icon: Icons.inventory,
                            value: '${totalVolume.toStringAsFixed(1)} m³',
                            label: 'Posekano',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Parcels list
                  Expanded(
                    child: _parcels.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.park_outlined,
                                  size: 64,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Ni še parcel',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.grey[500],
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Uvozite KML, narišite parcelo ali\ndolgo pritisnite na karti za uvoz iz katastra',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  onPressed: _importKml,
                                  icon: const Icon(Icons.file_upload),
                                  label: const Text('Uvozi KML'),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _addParcel,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Dodaj parcelo'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _parcels.length,
                            itemBuilder: (context, index) {
                              final parcel = _parcels[index];

                              return Dismissible(
                                key: Key('parcel_${parcel.id}'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  await _deleteParcel(parcel);
                                  return false; // We handle deletion ourselves
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red,
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    onTap: () => _openParcelDetail(parcel),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: parcel.polygon.isNotEmpty
                                        ? ParcelSilhouette(
                                            polygon: parcel.polygon,
                                            size: 48,
                                            fillColor: getForestTypeIcon(parcel.forestType).$2.withValues(alpha: 0.3),
                                            strokeColor: getForestTypeIcon(parcel.forestType).$2,
                                          )
                                        : Icon(
                                            getForestTypeIcon(parcel.forestType).$1,
                                            color: getForestTypeIcon(parcel.forestType).$2,
                                          ),
                                    title: Text(
                                      parcel.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (parcel.owner != null && parcel.owner!.isNotEmpty)
                                          Text(
                                            parcel.owner!,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        Row(
                                          children: [
                                            Text(parcel.areaFormatted),
                                            if (parcel.treesCut > 0 || parcel.woodCut > 0) ...[
                                              Text(' · ', style: TextStyle(color: Colors.grey[400])),
                                              if (parcel.treesCut > 0)
                                                Text(
                                                  '${parcel.treesCut} dreves',
                                                  style: TextStyle(color: Colors.orange[700]),
                                                ),
                                              if (parcel.treesCut > 0 && parcel.woodCut > 0)
                                                Text(' · ', style: TextStyle(color: Colors.grey[400])),
                                              if (parcel.woodCut > 0)
                                                Text(
                                                  '${parcel.woodCut.toStringAsFixed(1)} m³',
                                                  style: TextStyle(color: Colors.orange[700]),
                                                ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: parcel.woodAllowance > 0
                                        ? SizedBox(
                                            width: 50,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '${parcel.woodUsedPercent.toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: parcel.woodUsedPercent >= 100
                                                        ? Colors.red
                                                        : parcel.woodUsedPercent >= 80
                                                            ? Colors.orange
                                                            : Colors.green,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(2),
                                                  child: LinearProgressIndicator(
                                                    value: parcel.woodUsedPercent / 100,
                                                    minHeight: 4,
                                                    backgroundColor: Colors.grey[300],
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      parcel.woodUsedPercent >= 100
                                                          ? Colors.red
                                                          : parcel.woodUsedPercent >= 80
                                                              ? Colors.orange
                                                              : Colors.green,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const Icon(Icons.chevron_right),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
        ),
      ],
    );
  }
}


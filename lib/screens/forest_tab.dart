import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/parcel.dart';
import '../providers/map_provider.dart';
import '../services/database_service.dart';
import '../services/kml_service.dart';
import '../services/analytics_service.dart';
import '../widgets/parcel_silhouette.dart';
import 'parcel_editor.dart';
import 'parcel_detail_screen.dart';
import '../main.dart' show MainScreen;

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
  String? _selectedOwnerFilter; // null means show all

  /// Get unique owners from all parcels
  List<String> get _uniqueOwners {
    final owners = _parcels
        .map((p) => p.owner)
        .where((owner) => owner != null && owner.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    owners.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return owners;
  }

  /// Get filtered parcels based on selected owner
  List<Parcel> get _filteredParcels {
    if (_selectedOwnerFilter == null) {
      return _parcels;
    }
    return _parcels
        .where((p) => p.owner == _selectedOwnerFilter)
        .toList();
  }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Napaka pri nalaganju: $e')));
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
        AnalyticsService().logParcelAdded(areaMSquared: result.areaM2);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Parcela dodana')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Napaka pri dodajanju: $e')));
        }
      }
    }
  }

  /// Public method to open a specific parcel detail (can be called from outside)
  Future<void> openParcelDetail(Parcel parcel) async {
    await _openParcelDetail(parcel);
  }

  Future<void> _openParcelDetail(Parcel parcel) async {
    AnalyticsService().logParcelViewed();
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
        content: Text(
          'Ali ste prepričani, da želite izbrisati "${parcel.name}"?\n\n'
          'Izbrisane bodo tudi vse točke, sečnje in hlodovina znotraj parcele.',
        ),
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
        final deleted = await _databaseService.deleteParcelWithContents(
          parcel.id,
        );
        await _loadData();
        AnalyticsService().logParcelDeleted();
        // Notify map provider to refresh parcels, logs, and locations on map
        if (mounted) {
          final mapProvider = context.read<MapProvider>();
          mapProvider.loadParcels();
          mapProvider.loadGeolocatedLogs();
          mapProvider.loadLocations();
        }
        if (mounted) {
          final logsCount = deleted['logs'] ?? 0;
          final locationsCount = deleted['locations'] ?? 0;
          final extras = <String>[];
          if (logsCount > 0) extras.add('$logsCount hlodov');
          if (locationsCount > 0) extras.add('$locationsCount točk');
          final extraText = extras.isNotEmpty ? ' (${extras.join(', ')})' : '';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Parcela izbrisana$extraText')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Napaka pri brisanju: $e')));
        }
      }
    }
  }

  Future<void> _exportKml() async {
    if (_parcels.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ni parcel za izvoz')));
      return;
    }

    try {
      await KmlService.exportToKml(_parcels);
      AnalyticsService().logParcelExportedKml(count: _parcels.length);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('KML uspešno izvožen')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Napaka pri izvozu: $e')));
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

      // Try to import as full parcel export first (with logs, sečnja, locations)
      final fullImport = KmlService.importParcelWithData(content);

      if (fullImport != null && fullImport.totalItems > 0) {
        // This is a full parcel export
        await _importFullParcel(fullImport);
        return;
      }

      // Fall back to simple parcel import
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
        AnalyticsService().logParcelImportedKml(count: parcels.length);
        if (mounted) {
          final totalArea = parcels.fold(
            0.0,
            (double sum, p) => sum + p.areaM2,
          );
          final areaFormatted = totalArea >= 10000
              ? '${(totalArea / 10000).toStringAsFixed(2)} ha'
              : '${totalArea.toStringAsFixed(0)} m²';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Uvoženih ${parcels.length} parcel ($areaFormatted)',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Napaka pri uvozu: $e')));
      }
    }
  }

  Future<void> _importFullParcel(ParcelImportData data) async {
    if (!mounted) return;

    // Build description of what will be imported
    final items = <String>[];
    items.add('Parcela: ${data.parcel.name}');
    if (data.logs.isNotEmpty) {
      items.add('${data.logs.length} hlodov');
    }
    if (data.secnja.isNotEmpty) {
      items.add('${data.secnja.length} sečenj');
    }
    if (data.locations.isNotEmpty) {
      items.add('${data.locations.length} točk');
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uvozi parcelo s podatki'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Najdeno:'),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(item),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Uvozim vse podatke?'),
          ],
        ),
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

    if (confirmed != true) return;

    try {
      // Insert parcel and get ID
      final parcelId = await _databaseService.insertParcel(data.parcel);

      // Insert logs with parcel ID
      for (final log in data.logs) {
        final logWithParcel = log.copyWith(parcelId: parcelId);
        await _databaseService.insertLog(logWithParcel);
      }

      // Insert sečnja locations
      for (final loc in data.secnja) {
        await _databaseService.insertLocation(loc);
      }

      // Insert regular locations
      for (final loc in data.locations) {
        await _databaseService.insertLocation(loc);
      }

      await _loadData();
      AnalyticsService().logParcelImportedKml(count: 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uvožena parcela "${data.parcel.name}" z ${data.totalItems} elementi',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Napaka pri uvozu: $e')));
      }
    }
  }

  Future<void> _showOwnerFilterDialog() async {
    final owners = _uniqueOwners;

    if (owners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ni parcel z določenimi lastniki')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.filter_list),
                  const SizedBox(width: 8),
                  Text(
                    'Filtriraj po lastniku',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // "Show all" option
            ListTile(
              leading: Icon(
                Icons.clear_all,
                color: _selectedOwnerFilter == null
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: const Text('Prikaži vse'),
              selected: _selectedOwnerFilter == null,
              onTap: () {
                setState(() => _selectedOwnerFilter = null);
                AnalyticsService().logOwnerFilterApplied(hasFilter: false);
                Navigator.of(context).pop();
              },
            ),
            const Divider(height: 1),
            // Owner options
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: owners.length,
                itemBuilder: (context, index) {
                  final owner = owners[index];
                  final parcelCount = _parcels
                      .where((p) => p.owner == owner)
                      .length;
                  final isSelected = _selectedOwnerFilter == owner;

                  return ListTile(
                    leading: Icon(
                      Icons.person,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(owner),
                    subtitle: Text('$parcelCount parcel'),
                    selected: isSelected,
                    onTap: () {
                      setState(() => _selectedOwnerFilter = owner);
                      AnalyticsService().logOwnerFilterApplied(hasFilter: true);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use filtered parcels for display
    final displayParcels = _filteredParcels;

    // Calculate totals from filtered parcel data
    final totalArea = displayParcels.fold(0.0, (double sum, p) => sum + p.areaM2);
    final totalAreaFormatted = totalArea >= 10000
        ? '${(totalArea / 10000).toStringAsFixed(2)} ha'
        : '${totalArea.toStringAsFixed(0)} m²';

    // Sum up wood cut and trees from filtered parcels
    int totalTrees = 0;
    double totalVolume = 0.0;
    for (final parcel in displayParcels) {
      totalTrees += parcel.treesCut;
      totalVolume += parcel.woodCut;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moj Gozd'),
        actions: [
          // Owner filter button
          IconButton(
            icon: Badge(
              isLabelVisible: _selectedOwnerFilter != null,
              child: const Icon(Icons.person),
            ),
            tooltip: 'Filtriraj po lastniku',
            onPressed: _showOwnerFilterDialog,
          ),
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
                            value: '${displayParcels.length}',
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
                    child: displayParcels.isEmpty
                        ? Center(
                            child: _selectedOwnerFilter != null
                                // Filter active but no matching parcels
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_off,
                                        size: 64,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Ni parcel za "$_selectedOwnerFilter"',
                                        style: Theme.of(context).textTheme.titleLarge
                                            ?.copyWith(color: Colors.grey[500]),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() => _selectedOwnerFilter = null);
                                        },
                                        icon: const Icon(Icons.clear_all),
                                        label: const Text('Prikaži vse'),
                                      ),
                                    ],
                                  )
                                // No parcels at all
                                : Column(
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
                                        style: Theme.of(context).textTheme.titleLarge
                                            ?.copyWith(color: Colors.grey[500]),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Narišite parcelo ali\niščite parcelo v katastru',
                                        style: Theme.of(context).textTheme.bodyMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      FilledButton.icon(
                                        onPressed: () => MainScreen.navigateToMapWithSearch(),
                                        icon: const Icon(Icons.search),
                                        label: const Text('Išči parcelo'),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _addParcel,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Dodaj parcelo'),
                                      ),
                                    ],
                                  ),
                          )
                        : _buildGroupedParcelsList(context, displayParcels),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupedParcelsList(
    BuildContext context,
    List<Parcel> parcels,
  ) {
    // Group parcels by cadastral municipality (KO)
    final groupedParcels = <String, List<Parcel>>{};
    for (final parcel in parcels) {
      final ko = parcel.cadastralMunicipality != null
          ? 'KO ${parcel.cadastralMunicipality}'
          : 'Brez KO';
      if (!groupedParcels.containsKey(ko)) {
        groupedParcels[ko] = [];
      }
      groupedParcels[ko]!.add(parcel);
    }

    // Progressive enhancement: only show grouping if more than one KO
    if (groupedParcels.length <= 1) {
      return _buildSimpleParcelsList(context, parcels);
    }

    // Sort KOs, but put "Brez KO" at the end
    final sortedKOs = groupedParcels.keys.toList()
      ..sort((a, b) {
        if (a == 'Brez KO') return 1;
        if (b == 'Brez KO') return -1;
        // Extract numeric KO for proper sorting
        final aNum = int.tryParse(a.replaceAll('KO ', ''));
        final bNum = int.tryParse(b.replaceAll('KO ', ''));
        if (aNum != null && bNum != null) {
          return aNum.compareTo(bNum);
        }
        return a.compareTo(b);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKOs.length,
      itemBuilder: (context, groupIndex) {
        final ko = sortedKOs[groupIndex];
        final groupParcels = groupedParcels[ko]!;
        final count = groupParcels.length;
        final totalArea = groupParcels.fold<double>(
          0,
          (sum, parcel) => sum + parcel.areaM2,
        );
        final areaFormatted = totalArea >= 10000
            ? '${(totalArea / 10000).toStringAsFixed(2)} ha'
            : '${totalArea.toStringAsFixed(0)} m²';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KO header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: EdgeInsets.only(top: groupIndex == 0 ? 0 : 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 20,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ko,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$count parcel • $areaFormatted',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            // Parcels in this group
            ...groupParcels.map((parcel) => _buildParcelCard(context, parcel)),
          ],
        );
      },
    );
  }

  Widget _buildSimpleParcelsList(BuildContext context, List<Parcel> parcels) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: parcels.length,
      itemBuilder: (context, index) {
        final parcel = parcels[index];
        return _buildParcelCard(context, parcel);
      },
    );
  }

  Widget _buildParcelCard(BuildContext context, Parcel parcel) {
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: parcel.polygon.isNotEmpty
              ? ParcelSilhouette(
                  polygon: parcel.polygon,
                  size: 48,
                  fillColor: getForestTypeIcon(parcel.forestType)
                      .$2
                      .withValues(alpha: 0.3),
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
                    Text(
                      ' · ',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    if (parcel.treesCut > 0)
                      Text(
                        '${parcel.treesCut} dreves',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    if (parcel.treesCut > 0 && parcel.woodCut > 0)
                      Text(
                        ' · ',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
        ),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/parcel.dart';
import '../providers/map_provider.dart';
import '../router/navigation_notifier.dart';
import '../router/route_names.dart';
import '../services/database_service.dart';
import '../services/ko_locator.dart';
import '../services/kml_service.dart';
import '../services/owner_lookup_service.dart';
import '../widgets/owner_list.dart';
import '../widgets/parcel_silhouette.dart';

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
    // Co-owners count separately, so a shared parcel lists under each.
    final owners = _parcels.expand(_ownersForParcel).toSet().toList();
    owners.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return owners;
  }

  /// Get filtered parcels based on selected owner
  List<Parcel> get _filteredParcels {
    if (_selectedOwnerFilter == null) {
      return _parcels;
    }
    return _parcels
        .where((p) => _ownersForParcel(p).contains(_selectedOwnerFilter))
        .toList();
  }

  List<String> _ownersForParcel(Parcel parcel) =>
      OwnerInfo.split(_ownerForParcel(parcel));

  String? _ownerForParcel(Parcel parcel) {
    if (parcel.owner != null && parcel.owner!.isNotEmpty) return parcel.owner;
    if (!parcel.isCadastral) return null;
    return OwnerLookupService.instance
        .lookup(parcel.cadastralMunicipality, parcel.parcelNumber)
        ?.displayOwners;
  }

  @override
  void initState() {
    super.initState();
    // KO names for the group headers; rebuild once the index is in.
    KoLocator.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
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
        ).showSnackBar(SnackBar(content: Text(context.l10n.forestLoadError('$e'))));
      }
    }
  }


  /// Public method to open a specific parcel detail (can be called from outside)
  Future<void> openParcelDetail(Parcel parcel) async {
    await _openParcelDetail(parcel);
  }

  Future<void> _openParcelDetail(Parcel parcel) async {
    // push() completes when the detail screen pops — only then reload, so a
    // parcel deleted or edited there disappears/updates without a pull-down.
    await context.push(
      AppRoutes.parcelDetail(parcel.id),
      extra: parcel,
    );
    if (!mounted) return;
    await _loadData();
  }

  Future<void> _deleteParcel(Parcel parcel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.forestDeleteTitle),
        content: Text(context.l10n.forestDeleteConfirm(parcel.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.commonDelete),
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
          if (logsCount > 0) {
            extras.add(context.l10n.logsCountLogs(logsCount));
          }
          if (locationsCount > 0) {
            extras.add(context.l10n.forestCountPoints(locationsCount));
          }
          final extraText = extras.isNotEmpty ? ' (${extras.join(', ')})' : '';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.forestDeleted(extraText))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.forestDeleteError('$e'))));
        }
      }
    }
  }

  Future<void> _exportKml() async {
    if (_parcels.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.forestNoParcelsToExport)));
      return;
    }

    try {
      await KmlService.exportToKml(_parcels);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.forestKmlExported)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.forestExportError('$e'))));
      }
    }
  }

  /// Read a picked KML, or the first .kml inside a KMZ.
  Future<String> _readKml(String path) async {
    if (!path.toLowerCase().endsWith('.kmz')) {
      return File(path).readAsString();
    }
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final kml = archive.files.firstWhere(
      (f) => f.isFile && f.name.toLowerCase().endsWith('.kml'),
      orElse: () => throw FormatException(L10n.current.forestImportNoParcels),
    );
    return utf8.decode(kml.content);
  }

  Future<void> _importKml() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['kml', 'kmz'],
      );
      final path = picked?.path;
      if (path == null) return;
      final content = await _readKml(path);

      // A single-parcel export from Gozdar also carries logs, fellings and
      // points; import it with all of them.
      final full = KmlService.importParcelWithData(content);
      if (full != null && full.totalItems > 0) {
        await _importFullParcel(full);
        return;
      }

      final parcels = KmlService.importFromKml(content);
      if (!mounted) return;
      if (parcels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.forestImportNoParcels)),
        );
        return;
      }

      final count = context.l10n.forestCountParcels(parcels.length);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.forestImportTitle),
          content: Text(context.l10n.forestImportConfirm(count)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.forestImportButton),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      for (final parcel in parcels) {
        await _databaseService.insertParcel(parcel);
      }
      await _loadData();
      if (!mounted) return;
      final totalArea = parcels.fold(0.0, (double sum, p) => sum + p.areaM2);
      final area = totalArea >= 10000
          ? '${(totalArea / 10000).toStringAsFixed(2)} ha'
          : '${totalArea.toStringAsFixed(0)} m²';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.forestImportDone(count, area))),
      );
    } catch (e) {
      if (mounted) {
        final message = e is FormatException ? e.message : '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.forestImportError(message))),
        );
      }
    }
  }

  Future<void> _importFullParcel(ParcelImportData data) async {
    if (!mounted) return;
    final items = [
      data.parcel.name,
      if (data.logs.isNotEmpty) context.l10n.logsCountLogs(data.logs.length),
      if (data.secnja.isNotEmpty)
        context.l10n.forestImportFellings(data.secnja.length),
      if (data.locations.isNotEmpty)
        context.l10n.forestCountPoints(data.locations.length),
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.forestImportFullTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.forestImportFound),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.forestImportButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final parcelId = await _databaseService.insertParcel(data.parcel);
      for (final log in data.logs) {
        await _databaseService.insertLog(log.copyWith(parcelId: parcelId));
      }
      for (final loc in [...data.secnja, ...data.locations]) {
        await _databaseService.insertLocation(loc);
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.forestImportFullDone(data.parcel.name)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.forestImportError('$e'))),
        );
      }
    }
  }

  Future<void> _showOwnerFilterDialog() async {
    final owners = _uniqueOwners;

    if (owners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.forestNoOwners)),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
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
                    context.l10n.forestFilterByOwner,
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
              title: Text(context.l10n.forestShowAll),
              selected: _selectedOwnerFilter == null,
              onTap: () {
                setState(() => _selectedOwnerFilter = null);
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
                      .where((p) => _ownersForParcel(p).contains(owner))
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
                    subtitle: Text(context.l10n.forestCountParcels(parcelCount)),
                    selected: isSelected,
                    onTap: () {
                      setState(() => _selectedOwnerFilter = owner);
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
    final totalArea = displayParcels.fold(
      0.0,
      (double sum, p) => sum + p.areaM2,
    );
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
        title: Text(context.l10n.forestTitle),
        actions: [
          // Filter own parcels by owner.
          IconButton(
            icon: Badge(
              isLabelVisible: _selectedOwnerFilter != null,
              child: const Icon(Icons.person),
            ),
            tooltip: context.l10n.forestFilterByOwner,
            onPressed: _showOwnerFilterDialog,
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.forestMoreOptionsTooltip,
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'import') {
                _importKml();
              } else if (value == 'export') {
                _exportKml();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    const Icon(Icons.file_upload),
                    const SizedBox(width: 8),
                    Text(context.l10n.forestImportKml),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.file_download),
                    const SizedBox(width: 8),
                    Text(context.l10n.forestExportKml),
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
                            label: context.l10n.forestSummaryArea,
                          ),
                          _SummaryItem(
                            icon: Icons.grid_view,
                            value: '${displayParcels.length}',
                            label: context.l10n.forestSummaryParcels,
                          ),
                          _SummaryItem(
                            icon: Icons.nature,
                            value: '$totalTrees',
                            label: context.l10n.forestSummaryTrees,
                          ),
                          _SummaryItem(
                            icon: Icons.inventory,
                            value: '${totalVolume.toStringAsFixed(1)} m³',
                            label: context.l10n.forestSummaryCut,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Parcels list
                  Expanded(
                    child: displayParcels.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Center(
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
                                        context.l10n.forestNoParcelsForOwner(_selectedOwnerFilter!),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(color: Colors.grey[500]),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(
                                            () => _selectedOwnerFilter = null,
                                          );
                                        },
                                        icon: const Icon(Icons.clear_all),
                                        label: Text(context.l10n.forestShowAll),
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
                                        context.l10n.forestEmptyTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(color: Colors.grey[500]),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        context.l10n.forestEmptyHint,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      Tooltip(
                                        message: context.l10n.forestSearchParcel,
                                        child: FilledButton.icon(
                                          onPressed: () {
                                            context.read<NavigationNotifier>().navigateToMapWithSearch();
                                            context.go(AppRoutes.map);
                                          },
                                          icon: const Icon(Icons.search),
                                          label: Text(context.l10n.forestSearchParcel),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: _importKml,
                                        icon: const Icon(Icons.file_upload),
                                        label: Text(context.l10n.forestImportKml),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : _buildGroupedParcelsList(context, displayParcels),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupedParcelsList(BuildContext context, List<Parcel> parcels) {
    // Group parcels by cadastral municipality (KO)
    final noKo = context.l10n.forestNoKo;
    final groupedParcels = <String, List<Parcel>>{};
    for (final parcel in parcels) {
      final ko = parcel.cadastralMunicipality != null
          ? context.l10n.forestKoLabel('${parcel.cadastralMunicipality}')
          : noKo;
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
        if (a == noKo) return 1;
        if (b == noKo) return -1;
        // Extract numeric KO for proper sorting
        final aNum = int.tryParse(
          '${groupedParcels[a]!.first.cadastralMunicipality}',
        );
        final bNum = int.tryParse(
          '${groupedParcels[b]!.first.cadastralMunicipality}',
        );
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
        // Label the group with the cadastral municipality (KO) name, e.g.
        // "STARI TRG (1650)" instead of "KO 1650", from the owners DB or the
        // bundled KO index.
        final sifko = groupParcels.first.cadastralMunicipality;
        final koName = OwnerLookupService.instance.koName(sifko) ??
            KoLocator.instance.bySifko(sifko)?.name;
        final koLabel = koName != null ? '$koName ($sifko)' : ko;
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: EdgeInsets.only(top: groupIndex == 0 ? 0 : 16, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      koLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${context.l10n.forestCountParcels(count)} • $areaFormatted',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final owners = _ownersForParcel(parcel);
    final owner = ownerSummary(owners);
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
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
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
                  fillColor: getForestTypeIcon(
                    parcel.forestType,
                  ).$2.withValues(alpha: 0.3),
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
              if (owner.isNotEmpty)
                Text(
                  owner,
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
                        context.l10n.forestCountTrees(parcel.treesCut),
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

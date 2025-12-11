import 'package:flutter/material.dart';
import '../models/map_layer.dart';

/// Modern bottom sheet for selecting map base layer and overlays
class MapLayerSelector extends StatefulWidget {
  final MapLayer currentBaseLayer;
  final Set<MapLayerType> activeOverlays;
  final String? workerUrl;
  final ValueChanged<MapLayer> onBaseLayerChanged;
  final ValueChanged<MapLayerType> onOverlayToggled;
  final VoidCallback? onImportFile;
  final VoidCallback? onDownloadTiles;

  const MapLayerSelector({
    super.key,
    required this.currentBaseLayer,
    required this.activeOverlays,
    required this.workerUrl,
    required this.onBaseLayerChanged,
    required this.onOverlayToggled,
    this.onImportFile,
    this.onDownloadTiles,
  });

  /// Show the layer selector as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required MapLayer currentBaseLayer,
    required Set<MapLayerType> activeOverlays,
    required String? workerUrl,
    required ValueChanged<MapLayer> onBaseLayerChanged,
    required ValueChanged<MapLayerType> onOverlayToggled,
    VoidCallback? onImportFile,
    VoidCallback? onDownloadTiles,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: MapLayerSelector(
            currentBaseLayer: currentBaseLayer,
            activeOverlays: activeOverlays,
            workerUrl: workerUrl,
            onBaseLayerChanged: onBaseLayerChanged,
            onOverlayToggled: onOverlayToggled,
            onImportFile: onImportFile,
            onDownloadTiles: onDownloadTiles,
          ),
        ),
      ),
    );
  }

  @override
  State<MapLayerSelector> createState() => _MapLayerSelectorState();
}

class _MapLayerSelectorState extends State<MapLayerSelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final String _searchQuery = '';
  final Map<OverlayCategory, bool> _expandedCategories = {};

  // Local state for selections
  late MapLayer _selectedBaseLayer;
  late Set<MapLayerType> _selectedOverlays;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize local state from widget
    _selectedBaseLayer = widget.currentBaseLayer;
    _selectedOverlays = Set.from(widget.activeOverlays);

    // Expand categories that have active overlays
    for (final category in OverlayCategory.values) {
      final hasActiveOverlay =
          MapLayer.overlaysByCategory[category]?.any(
            (layer) => _selectedOverlays.contains(layer.type),
          ) ??
          false;
      _expandedCategories[category] = hasActiveOverlay;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header with tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sloji karte',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: const [
                Tab(
                  height: 56,
                  icon: Icon(Icons.layers, size: 22),
                  iconMargin: EdgeInsets.only(bottom: 4),
                  text: 'Podlaga',
                ),
                Tab(
                  height: 56,
                  icon: Icon(Icons.tune, size: 22),
                  iconMargin: EdgeInsets.only(bottom: 4),
                  text: 'Prekrivni sloji',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildBaseLayersTab(), _buildOverlaysTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseLayersTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // International base layers
        _buildBaseLayerSection('Mednarodne karte', [
          MapLayer.openStreetMap,
          MapLayer.openTopoMap,
          MapLayer.esriWorldImagery,
          MapLayer.esriTopoMap,
          MapLayer.googleHybrid,
        ]),
        const SizedBox(height: 16),
        // Slovenian base layers
        _buildBaseLayerSection('Slovenske karte', [
          MapLayer.ortofoto,
          MapLayer.ortofoto2023,
          MapLayer.ortofoto2022,
          MapLayer.dofIr,
          MapLayer.dmr,
        ]),
        const SizedBox(height: 24),
        // Download tiles button
        if (widget.onDownloadTiles != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onDownloadTiles!();
              },
              icon: const Icon(Icons.download, size: 20),
              label: const Text('Prenesi za delo brez povezave'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBaseLayerSection(String title, List<MapLayer> layers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...layers.map((layer) => _buildBaseLayerCard(layer)),
      ],
    );
  }

  Widget _buildBaseLayerCard(MapLayer layer) {
    final isSelected = _selectedBaseLayer.type == layer.type;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedBaseLayer = layer;
          });
          widget.onBaseLayerChanged(layer);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getBaseLayerIcon(layer.type),
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layer.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      layer.attribution,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Check icon
              if (isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlaysTab() {
    return Column(
      children: [
        // Hint for Slovenian layers
        if (!_selectedBaseLayer.isSlovenian && widget.workerUrl == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Slovenski sloji so na voljo le z Ortofoto ali DMR podlago.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Import button
        if (widget.onImportFile != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onImportFile!();
              },
              icon: const Icon(Icons.file_upload, size: 20),
              label: const Text('Uvozi geodatke (KML, KMZ, GeoPackage)'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        // Category list
        Expanded(child: _buildCategoryList()),
      ],
    );
  }

  Widget _buildCategoryList() {
    final categories = MapLayer.overlaysByCategory.entries.where((entry) {
      final layers = entry.value.where((layer) {
        // Filter by search query
        if (_searchQuery.isNotEmpty &&
            !layer.name.toLowerCase().contains(_searchQuery)) {
          return false;
        }
        // Filter by Slovenian availability
        if (!layer.isSlovenian) return true;
        return _selectedBaseLayer.isSlovenian || widget.workerUrl != null;
      }).toList();
      return layers.isNotEmpty;
    }).toList();

    if (categories.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Ni rezultatov',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final entry = categories[index];
        return _buildCategoryCard(entry.key, entry.value);
      },
    );
  }

  Widget _buildCategoryCard(OverlayCategory category, List<MapLayer> layers) {
    final filteredLayers = layers.where((layer) {
      // Filter by search query
      if (_searchQuery.isNotEmpty &&
          !layer.name.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      // Filter by Slovenian availability
      if (!layer.isSlovenian) return true;
      return _selectedBaseLayer.isSlovenian || widget.workerUrl != null;
    }).toList();

    if (filteredLayers.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedCategories[category] ?? false;
    final activeCount = filteredLayers
        .where((layer) => _selectedOverlays.contains(layer.type))
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () {
              setState(() {
                _expandedCategories[category] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Category icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(category),
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overlayCategoryNames[category] ?? category.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (activeCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$activeCount aktivnih',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Expand icon
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // Layers list
          if (isExpanded)
            Column(
              children: filteredLayers
                  .map((layer) => _buildOverlayTile(layer))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlayTile(MapLayer layer) {
    final isActive = _selectedOverlays.contains(layer.type);

    return InkWell(
      onTap: () {
        setState(() {
          if (isActive) {
            _selectedOverlays.remove(layer.type);
          } else {
            _selectedOverlays.add(layer.type);
          }
        });
        widget.onOverlayToggled(layer.type);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 40,
              height: 40,
              child: Checkbox(
                value: isActive,
                onChanged: (_) {
                  setState(() {
                    if (isActive) {
                      _selectedOverlays.remove(layer.type);
                    } else {
                      _selectedOverlays.add(layer.type);
                    }
                  });
                  widget.onOverlayToggled(layer.type);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Layer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layer.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (layer.attribution.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      layer.attribution,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBaseLayerIcon(MapLayerType type) {
    switch (type) {
      case MapLayerType.openStreetMap:
        return Icons.map;
      case MapLayerType.openTopoMap:
      case MapLayerType.esriTopoMap:
        return Icons.terrain;
      case MapLayerType.esriWorldImagery:
      case MapLayerType.googleHybrid:
        return Icons.satellite_alt;
      case MapLayerType.ortofoto:
      case MapLayerType.ortofoto2023:
      case MapLayerType.ortofoto2022:
        return Icons.image;
      case MapLayerType.dofIr:
        return Icons.gradient;
      case MapLayerType.dmr:
        return Icons.view_in_ar;
      default:
        return Icons.layers;
    }
  }

  IconData _getCategoryIcon(OverlayCategory category) {
    switch (category) {
      case OverlayCategory.administrativno:
        return Icons.location_city;
      case OverlayCategory.infrastruktura:
        return Icons.route;
      case OverlayCategory.gozdnoGospodarstvo:
        return Icons.park;
      case OverlayCategory.zavarovanaObmocja:
        return Icons.nature;
      case OverlayCategory.nevarnostiInSkode:
        return Icons.warning;
      case OverlayCategory.funkcijeGozda:
        return Icons.eco;
      case OverlayCategory.posebno:
        return Icons.pets;
    }
  }
}

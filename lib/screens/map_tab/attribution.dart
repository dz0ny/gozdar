part of '../map_tab.dart';

/// Usage rights and attribution.
extension _Attribution on MapTabState {
  void _showUsageRightsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Material(
            // ListTiles paint their background and ink on the nearest
            // Material; this one sits above the sheet's colour.
            type: MaterialType.transparency,
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    L10n.current.mapTabUsageRightsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Croatian users see their own source first.
                      if (L10n.current.localeName == 'hr')
                        _buildUsageRightsSection(
                          context,
                          L10n.current.mapTabUsageDguName,
                          'DGU',
                          L10n.current.mapTabUsageDguDesc,
                          'https://oss.uredjenazemlja.hr/',
                        ),
                      _buildUsageRightsSection(
                        context,
                        L10n.current.mapTabUsageGuName,
                        'prostor.zgs.gov.si',
                        L10n.current.mapTabUsageGuDesc,
                        'https://www.gov.si/drzavni-organi/organi-v-sestavi/geodetska-uprava/',
                      ),
                      _buildUsageRightsSection(
                        context,
                        L10n.current.mapTabUsageZgsName,
                        'ZGS',
                        L10n.current.mapTabUsageZgsDesc,
                        'https://www.zgs.si/',
                      ),
                      if (L10n.current.localeName != 'hr')
                        _buildUsageRightsSection(
                          context,
                          L10n.current.mapTabUsageDguName,
                          'DGU',
                          L10n.current.mapTabUsageDguDesc,
                          'https://oss.uredjenazemlja.hr/',
                        ),
                      _buildUsageRightsSection(
                        context,
                        'OpenStreetMap',
                        'OSM',
                        L10n.current.mapTabUsageOsmDesc,
                        'https://www.openstreetmap.org/copyright',
                      ),
                      _buildUsageRightsSection(
                        context,
                        'ESRI',
                        'Esri',
                        L10n.current.mapTabUsageEsriDesc,
                        'https://www.esri.com/en-us/legal/terms/full-master-agreement',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                L10n.current.mapTabUsageDisclaimer,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a single usage rights section
  Widget _buildUsageRightsSection(
    BuildContext context,
    String title,
    String shortName,
    String description,
    String url,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  shortName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            url,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  /// Build attribution text from base layer and active overlays
  String _buildAttributionText() {
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    final attributions = <String>{};

    // Add base layer attribution
    if (mapProvider.currentBaseLayer.attribution.isNotEmpty) {
      attributions.add(mapProvider.currentBaseLayer.attribution);
    }

    // Add active overlay attributions
    for (final overlayType in mapProvider.activeOverlays) {
      final layer = MapLayer.overlayLayers.cast<MapLayer?>().firstWhere(
        (l) => l?.type == overlayType,
        orElse: () => null,
      );
      if (layer != null && layer.attribution.isNotEmpty) {
        attributions.add(layer.attribution);
      }
    }

    // Join unique attributions
    return attributions.join(' | ');
  }
}

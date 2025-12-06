import 'package:flutter/material.dart';
import '../models/map_layer.dart';

/// Bottom sheet for selecting map base layer and overlays
class MapLayerSelector extends StatelessWidget {
  final MapLayer currentBaseLayer;
  final Set<MapLayerType> activeOverlays;
  final String? workerUrl;
  final ValueChanged<MapLayer> onBaseLayerChanged;
  final ValueChanged<MapLayerType> onOverlayToggled;

  const MapLayerSelector({
    super.key,
    required this.currentBaseLayer,
    required this.activeOverlays,
    required this.workerUrl,
    required this.onBaseLayerChanged,
    required this.onOverlayToggled,
  });

  /// Show the layer selector as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required MapLayer currentBaseLayer,
    required Set<MapLayerType> activeOverlays,
    required String? workerUrl,
    required ValueChanged<MapLayer> onBaseLayerChanged,
    required ValueChanged<MapLayerType> onOverlayToggled,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => MapLayerSelector(
        currentBaseLayer: currentBaseLayer,
        activeOverlays: activeOverlays,
        workerUrl: workerUrl,
        onBaseLayerChanged: onBaseLayerChanged,
        onOverlayToggled: onOverlayToggled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Osnovni sloj',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              _buildBaseLayerSelector(context, setModalState),
              const SizedBox(height: 8),
              // Overlay layers grouped by category
              ..._buildOverlayCategories(context, setModalState),
              // Show hint when Slovenian overlays are hidden
              if (!currentBaseLayer.isSlovenian && workerUrl == null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Slovenski sloji (Kataster, Gozdne ceste...) so na voljo le z Ortofoto ali DTK25 podlago.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBaseLayerSelector(
    BuildContext context,
    StateSetter setModalState,
  ) {
    return RadioGroup<MapLayerType>(
      groupValue: currentBaseLayer.type,
      onChanged: (value) {
        if (value != null) {
          final layer = MapLayer.baseLayers.firstWhere((l) => l.type == value);
          onBaseLayerChanged(layer);
          setModalState(() {});
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: MapLayer.baseLayers
            .map(
              (layer) => RadioListTile<MapLayerType>(
                value: layer.type,
                title: Text(layer.name),
                subtitle: Text(
                  layer.attribution,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  List<Widget> _buildOverlayCategories(
    BuildContext context,
    StateSetter setModalState,
  ) {
    return MapLayer.overlaysByCategory.entries.expand((entry) {
      final category = entry.key;
      final layers = entry.value
          .where(
            (layer) =>
                !layer.isSlovenian ||
                currentBaseLayer.isSlovenian ||
                workerUrl != null,
          )
          .toList();

      if (layers.isEmpty) return <Widget>[];

      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            overlayCategoryNames[category] ?? category.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(height: 1),
        ...layers.map(
          (layer) => CheckboxListTile(
            value: activeOverlays.contains(layer.type),
            onChanged: (value) {
              onOverlayToggled(layer.type);
              setModalState(() {});
            },
            title: Text(layer.name),
            subtitle: Text(
              layer.attribution,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ];
    }).toList();
  }
}

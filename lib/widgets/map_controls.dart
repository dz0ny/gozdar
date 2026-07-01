import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/map_layer.dart';

/// Floating action buttons for map controls (zoom, GPS, layers)
class MapControls extends StatelessWidget {
  final MapController mapController;
  final MapLayer currentBaseLayer;
  final int locationsCount;
  final VoidCallback onLayerSelectorPressed;
  final VoidCallback onGpsPressed;
  final VoidCallback? onLocationsPressed;
  final VoidCallback onSearchPressed;

  /// Hide the bottom-anchored controls (GPS + saved locations) so they don't
  /// overlap the measurement panel docked at the bottom of the map.
  final bool hideBottomControls;

  const MapControls({
    super.key,
    required this.mapController,
    required this.currentBaseLayer,
    required this.locationsCount,
    required this.onLayerSelectorPressed,
    required this.onGpsPressed,
    required this.onSearchPressed,
    this.onLocationsPressed,
    this.hideBottomControls = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top right: layers and zoom
        Positioned(
          top: 80,
          right: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'map_layers',
                mini: true,
                onPressed: onLayerSelectorPressed,
                tooltip: 'Izberi sloj',
                child: const Icon(Icons.layers),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'map_search',
                mini: true,
                onPressed: onSearchPressed,
                tooltip: 'Išči parcelo po KO',
                child: const Icon(Icons.search),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'map_zoom_in',
                mini: true,
                onPressed: _zoomIn,
                tooltip: 'Povečaj karto',
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'map_zoom_out',
                mini: true,
                onPressed: _zoomOut,
                tooltip: 'Pomanjšaj karto',
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
        // Bottom right: GPS (hidden while measuring to avoid overlap)
        if (!hideBottomControls)
          Positioned(
            bottom: 8,
            right: 4,
            child: FloatingActionButton(
              heroTag: 'map_gps',
              onPressed: onGpsPressed,
              tooltip: 'Centriraj na GPS lokacijo',
              child: const Icon(Icons.my_location),
            ),
          ),
        // Bottom left: Saved locations (only show if there are locations)
        if (!hideBottomControls &&
            locationsCount > 0 &&
            onLocationsPressed != null)
          Positioned(
            bottom: 8,
            left: 4,
            child: FloatingActionButton(
              heroTag: 'map_locations',
              onPressed: onLocationsPressed,
              tooltip: 'Shranjene lokacije',
              child: Badge(
                label: Text('$locationsCount'),
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                textColor: Theme.of(context).colorScheme.onTertiary,
                child: const Icon(Icons.location_on),
              ),
            ),
          ),
      ],
    );
  }

  void _zoomIn() {
    final camera = mapController.camera;
    final newZoom = camera.zoom + 1;
    if (newZoom <= MapLayer.appMaxZoom) {
      mapController.moveAndRotate(camera.center, newZoom, camera.rotation);
    }
  }

  void _zoomOut() {
    final camera = mapController.camera;
    final newZoom = camera.zoom - 1;
    if (newZoom >= 7.0) {
      mapController.moveAndRotate(camera.center, newZoom, camera.rotation);
    }
  }
}

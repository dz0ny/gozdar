import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_layer.dart';
import 'map_layer_renderer.dart';

/// Non-interactive embedded map preview of a parcel, using the same base layer
/// and overlays currently enabled on the main map. The parcel polygon is drawn
/// on top and the camera is fit to its bounds. Tapping opens the full map.
class ParcelMapPreview extends StatelessWidget {
  /// Parcel outline (WGS84) to draw and fit the camera to.
  final List<LatLng> polygon;

  /// Base layer currently selected on the main map.
  final MapLayer baseLayer;

  /// Overlays currently active on the main map.
  final Set<MapLayerType> activeOverlays;

  /// Worker proxy URL for Slovenian (WMS-proxied) layers.
  final String? workerUrl;

  /// Outline color for the parcel polygon (e.g. forest-type color).
  final Color outlineColor;

  /// Width-to-height ratio of the preview. Defaults to 1.0 (square — full
  /// content width).
  final double aspectRatio;
  final VoidCallback? onTap;

  const ParcelMapPreview({
    super.key,
    required this.polygon,
    required this.baseLayer,
    required this.activeOverlays,
    required this.workerUrl,
    required this.outlineColor,
    this.aspectRatio = 1.0,
    this.onTap,
  });

  /// Build base + overlay tile layers, falling back to ESRI World Imagery if
  /// the current base layer can't resolve (e.g. a Slovenian layer with no
  /// worker URL configured) so the preview never crashes.
  List<TileLayer> _tileLayers() {
    final resolvableBase = baseLayer.resolveUrlTemplate(workerUrl) != null
        ? baseLayer
        : MapLayer.esriWorldImagery;
    final renderer = MapLayerRenderer(
      baseLayer: resolvableBase,
      activeOverlays: activeOverlays,
      workerUrl: workerUrl,
    );
    return renderer.getAllTileLayers();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints(polygon);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              options: MapOptions(
                crs: const Epsg3857(),
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(32),
                  maxZoom: 18,
                ),
                minZoom: 7.0,
                maxZoom: MapLayer.appMaxZoom,
                // Static preview — interaction happens on the full map.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                ..._tileLayers(),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: polygon,
                      color: outlineColor.withValues(alpha: 0.25),
                      borderColor: outlineColor,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              ],
            ),
            // Tap target to open the full map.
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onTap),
                ),
              ),
            // "Open on map" affordance (only when tappable).
            if (onTap != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Karta',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

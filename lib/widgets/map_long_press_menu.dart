import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/parcel.dart';
import '../services/public_parcel_settings.dart';

/// Modal bottom sheet shown on map long press with location-based actions.
///
/// Rendered as a sheet (instead of a popup floating over the map tiles) so the
/// options stay readable regardless of the underlying imagery.
class MapLongPressMenu extends StatefulWidget {
  final VoidCallback onAddLocation;
  final VoidCallback onAddLog;
  final VoidCallback onAddSecnja;
  final VoidCallback onMeasureDistance;
  final VoidCallback onMeasureArea;
  final VoidCallback onImportParcel;
  final VoidCallback? onViewParcel;
  final Parcel? existingParcel;

  /// Whether an offline kataster (parcels DB) is available — gates the public
  /// owner-category highlight toggles, which colour imported parcels by owner
  /// type (state / municipality / company).
  final bool katasterAvailable;
  final void Function(PublicOwnerCategory category, bool value)
  onTogglePublicCategory;

  /// Whether a specific offline parcel sits under the long-press point — gates
  /// the (per-parcel) mejniki toggle.
  final bool mejnikiAvailable;
  final bool showMejniki;
  final ValueChanged<bool> onToggleMejniki;

  const MapLongPressMenu({
    super.key,
    required this.onAddLocation,
    required this.onAddLog,
    required this.onAddSecnja,
    required this.onMeasureDistance,
    required this.onMeasureArea,
    required this.onImportParcel,
    this.onViewParcel,
    this.existingParcel,
    required this.katasterAvailable,
    required this.onTogglePublicCategory,
    required this.mejnikiAvailable,
    required this.showMejniki,
    required this.onToggleMejniki,
  });

  /// Present the action menu as a modal bottom sheet. The selected action runs
  /// after the sheet is dismissed.
  static Future<void> show(
    BuildContext context, {
    required LatLng mapPosition,
    Parcel? existingParcel,
    required VoidCallback onAddLocation,
    required VoidCallback onAddLog,
    required VoidCallback onAddSecnja,
    required VoidCallback onMeasureDistance,
    required VoidCallback onMeasureArea,
    required VoidCallback onImportParcel,
    VoidCallback? onViewParcel,
    required bool katasterAvailable,
    required void Function(PublicOwnerCategory category, bool value)
    onTogglePublicCategory,
    required bool mejnikiAvailable,
    required bool showMejniki,
    required ValueChanged<bool> onToggleMejniki,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MapLongPressMenu(
        existingParcel: existingParcel,
        onAddLocation: onAddLocation,
        onAddLog: onAddLog,
        onAddSecnja: onAddSecnja,
        onMeasureDistance: onMeasureDistance,
        onMeasureArea: onMeasureArea,
        onImportParcel: onImportParcel,
        onViewParcel: onViewParcel,
        katasterAvailable: katasterAvailable,
        onTogglePublicCategory: onTogglePublicCategory,
        mejnikiAvailable: mejnikiAvailable,
        showMejniki: showMejniki,
        onToggleMejniki: onToggleMejniki,
      ),
    );
  }

  @override
  State<MapLongPressMenu> createState() => _MapLongPressMenuState();
}

class _MapLongPressMenuState extends State<MapLongPressMenu> {
  late final Set<PublicOwnerCategory> _publicOn = {
    for (final c in PublicOwnerCategory.values)
      if (PublicParcelSettings.instance.isOn(c)) c,
  };

  /// Compact action button: an icon over a short label, sized for a toolbar
  /// grid. Closes the sheet, then runs the action.
  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 80,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Actions as a compact icon toolbar instead of a tall list.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                _action(
                  icon: Icons.add_location_alt,
                  label: 'Točka',
                  color: Colors.red,
                  onTap: widget.onAddLocation,
                ),
                _action(
                  icon: Icons.forest,
                  label: 'Hlodovina',
                  color: Colors.brown,
                  onTap: widget.onAddLog,
                ),
                _action(
                  icon: Icons.carpenter,
                  label: 'Sečnja',
                  color: Colors.deepOrange,
                  onTap: widget.onAddSecnja,
                ),
                _action(
                  icon: Icons.route,
                  label: 'Razdalja',
                  color: Colors.teal,
                  onTap: widget.onMeasureDistance,
                ),
                _action(
                  icon: Icons.square_foot,
                  label: 'Površina',
                  color: Colors.deepPurple,
                  onTap: widget.onMeasureArea,
                ),
                if (widget.existingParcel != null)
                  _action(
                    icon: Icons.visibility,
                    label: 'Parcela',
                    color: Colors.blue,
                    onTap: () => widget.onViewParcel?.call(),
                  )
                else
                  _action(
                    icon: Icons.info_outline,
                    label: 'Info',
                    color: Colors.blue,
                    onTap: widget.onImportParcel,
                  ),
                if (widget.mejnikiAvailable)
                  _action(
                    icon: Icons.scatter_plot,
                    label: 'Mejniki',
                    color: widget.showMejniki ? Colors.orange : Colors.green,
                    onTap: () => widget.onToggleMejniki(!widget.showMejniki),
                  ),
              ],
            ),
            // Colour imported parcels by public-owner type. Chips stay on the
            // sheet so several categories can be flipped in place.
            if (widget.katasterAvailable) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Javne parcele',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final cat in PublicOwnerCategory.values)
                    FilterChip(
                      avatar: CircleAvatar(
                        radius: 8,
                        backgroundColor: cat.color,
                      ),
                      label: Text(cat.label),
                      selected: _publicOn.contains(cat),
                      selectedColor: cat.fillColor,
                      checkmarkColor: cat.color,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _publicOn.add(cat);
                          } else {
                            _publicOn.remove(cat);
                          }
                        });
                        widget.onTogglePublicCategory(cat, v);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

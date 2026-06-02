import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/parcel.dart';

/// Modal bottom sheet shown on map long press with location-based actions.
///
/// Rendered as a sheet (instead of a popup floating over the map tiles) so the
/// options stay readable regardless of the underlying imagery.
class MapLongPressMenu extends StatelessWidget {
  final VoidCallback onAddLocation;
  final VoidCallback onAddLog;
  final VoidCallback onAddSecnja;
  final VoidCallback onMeasureDistance;
  final VoidCallback onMeasureArea;
  final VoidCallback onImportParcel;
  final VoidCallback? onViewParcel;
  final Parcel? existingParcel;

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
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: () {
        // Close the sheet first, then run the action it triggers.
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuItem(
            context: context,
            icon: Icons.add_location_alt,
            label: 'Dodaj točko',
            color: Colors.red,
            onTap: onAddLocation,
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.forest,
            label: 'Dodaj hlodovino',
            color: Colors.brown,
            onTap: onAddLog,
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.carpenter,
            label: 'Označi sečnjo',
            color: Colors.deepOrange,
            onTap: onAddSecnja,
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.route,
            label: 'Merjenje razdalje',
            color: Colors.teal,
            onTap: onMeasureDistance,
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.square_foot,
            label: 'Merjenje površine',
            color: Colors.deepPurple,
            onTap: onMeasureArea,
          ),
          if (existingParcel != null)
            _buildMenuItem(
              context: context,
              icon: Icons.visibility,
              label: 'Poglej parcelo',
              color: Colors.blue,
              onTap: () => onViewParcel?.call(),
            )
          else
            _buildMenuItem(
              context: context,
              icon: Icons.download,
              label: 'Uvozi parcelo',
              color: Colors.blue,
              onTap: onImportParcel,
            ),
        ],
      ),
    );
  }
}

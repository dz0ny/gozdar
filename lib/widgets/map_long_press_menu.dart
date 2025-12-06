import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Popup menu shown on map long press with location-based actions
class MapLongPressMenu extends StatelessWidget {
  final Offset screenPosition;
  final LatLng mapPosition;
  final VoidCallback onAddLocation;
  final VoidCallback onAddLog;
  final VoidCallback onAddSecnja;
  final VoidCallback onImportParcel;
  final VoidCallback onDismiss;

  const MapLongPressMenu({
    super.key,
    required this.screenPosition,
    required this.mapPosition,
    required this.onAddLocation,
    required this.onAddLog,
    required this.onAddSecnja,
    required this.onImportParcel,
    required this.onDismiss,
  });

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: screenPosition.dx - 80,
      top: screenPosition.dy - 130,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add point button
              _buildMenuItem(
                icon: Icons.add_location_alt,
                label: 'Dodaj tocko',
                color: Colors.red,
                onTap: () {
                  onDismiss();
                  onAddLocation();
                },
              ),
              const Divider(height: 8),
              // Add log button
              _buildMenuItem(
                icon: Icons.forest,
                label: 'Dodaj hlodovino',
                color: Colors.brown,
                onTap: () {
                  onDismiss();
                  onAddLog();
                },
              ),
              const Divider(height: 8),
              // Add sečnja button
              _buildMenuItem(
                icon: Icons.carpenter,
                label: 'Označi sečnjo',
                color: Colors.deepOrange,
                onTap: () {
                  onDismiss();
                  onAddSecnja();
                },
              ),
              const Divider(height: 8),
              // Import parcel button
              _buildMenuItem(
                icon: Icons.download,
                label: 'Uvozi parcelo',
                color: Colors.blue,
                onTap: () {
                  onDismiss();
                  onImportParcel();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

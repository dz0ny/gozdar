import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_location.dart';
import '../services/cadastral_service.dart';

/// Helper class for map-related dialogs
class MapDialogs {
  MapDialogs._(); // Private constructor - static methods only

  /// Show dialog to add a new location
  /// Returns the name if confirmed, null if cancelled
  static Future<String?> showAddLocationDialog({
    required BuildContext context,
    required LatLng position,
  }) async {
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj lokacijo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lat: ${position.latitude.toStringAsFixed(6)}\n'
              'Lng: ${position.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Ime lokacije',
                hintText: 'Vnesite ime za to lokacijo',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prosim vnesite ime')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      return nameController.text.trim();
    }
    return null;
  }

  /// Show dialog to add a sečnja marker (tree to be cut)
  /// Returns the name/description if confirmed, null if cancelled
  static Future<String?> showAddSecnjaDialog({
    required BuildContext context,
    required LatLng position,
  }) async {
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.carpenter, color: Colors.deepOrange),
            const SizedBox(width: 8),
            const Text('Označi sečnjo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lat: ${position.latitude.toStringAsFixed(6)}\n'
              'Lng: ${position.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Opis drevesa',
                hintText: 'npr. Hrast, Bukev, Smreka...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Prekliči'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prosim vnesite opis')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            icon: const Icon(Icons.carpenter),
            label: const Text('Označi'),
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      return nameController.text.trim();
    }
    return null;
  }

  /// Show dialog to confirm location deletion
  /// Returns true if confirmed, false if cancelled
  static Future<bool> showDeleteLocationDialog({
    required BuildContext context,
    required MapLocation location,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izbriši lokacijo'),
        content: Text(
          'Ali ste prepričani, da želite izbrisati "${location.name}"?',
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

    return result ?? false;
  }

  /// Show dialog to edit location name
  /// Returns new name if confirmed, null if cancelled
  static Future<String?> showEditLocationDialog({
    required BuildContext context,
    required MapLocation location,
  }) async {
    final controller = TextEditingController(text: location.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preimenuj lokacijo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Ime',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Prekliči'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Shrani'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != location.name) {
      return newName;
    }
    return null;
  }

  /// Show dialog to import a cadastral parcel
  /// Returns true if import is confirmed, false if cancelled
  static Future<bool> showImportParcelDialog({
    required BuildContext context,
    required CadastralParcel cadastralParcel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uvozi parcelo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parcel info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.landscape, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Parcela ${cadastralParcel.parcelNumber}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      Icons.location_city,
                      'Katastrska obcina',
                      cadastralParcel.cadastralMunicipality.toString(),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      Icons.straighten,
                      'Povrsina',
                      cadastralParcel.formattedArea,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ali zelite uvoziti to parcelo v "Moj gozd"?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Preklici'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.download),
            label: const Text('Uvozi'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  static Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

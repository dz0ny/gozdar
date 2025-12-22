import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_location.dart';
import '../services/cadastral_service.dart';

/// Helper class for map-related dialogs
class MapDialogs {
  MapDialogs._(); // Private constructor - static methods only

  /// Show dialog to add a new location with editable coordinates
  /// Returns a record with (name, latitude, longitude) if confirmed, null if cancelled
  /// The position parameter pre-fills the coordinates from long-press
  static Future<({String name, double latitude, double longitude})?> showAddLocationDialog({
    required BuildContext context,
    required LatLng position,
  }) async {
    final nameController = TextEditingController();
    final latController = TextEditingController(text: position.latitude.toStringAsFixed(6));
    final lngController = TextEditingController(text: position.longitude.toStringAsFixed(6));
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_location_alt, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Dodaj lokacijo')),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koordinate iz dolgo-pritiska ali vnesite svoje',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: latController,
                  decoration: const InputDecoration(
                    labelText: 'Zemljepisna širina (Lat)',
                    hintText: 'npr. 46.0569',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.north),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vnesite širino';
                    }
                    final lat = double.tryParse(value.trim().replaceAll(',', '.'));
                    if (lat == null) {
                      return 'Neveljavna številka';
                    }
                    if (lat < -90 || lat > 90) {
                      return 'Širina mora biti med -90 in 90';
                    }
                    // Slovenia bounds check (rough)
                    if (lat < 45.4 || lat > 46.9) {
                      return 'Lokacija ni v Sloveniji (45.4-46.9)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lngController,
                  decoration: const InputDecoration(
                    labelText: 'Zemljepisna dolžina (Lng)',
                    hintText: 'npr. 14.5058',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.east),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vnesite dolžino';
                    }
                    final lng = double.tryParse(value.trim().replaceAll(',', '.'));
                    if (lng == null) {
                      return 'Neveljavna številka';
                    }
                    if (lng < -180 || lng > 180) {
                      return 'Dolžina mora biti med -180 in 180';
                    }
                    // Slovenia bounds check (rough)
                    if (lng < 13.3 || lng > 16.6) {
                      return 'Lokacija ni v Sloveniji (13.3-16.6)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ime lokacije',
                    hintText: 'Vnesite ime za to lokacijo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vnesite ime';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Prekliči'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            icon: const Icon(Icons.add_location),
            label: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (result == true) {
      final lat = double.parse(latController.text.trim().replaceAll(',', '.'));
      final lng = double.parse(lngController.text.trim().replaceAll(',', '.'));
      return (name: nameController.text.trim(), latitude: lat, longitude: lng);
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

  /// Show dialog to add a location by entering coordinates manually
  /// Returns a record with (name, latitude, longitude) if confirmed, null if cancelled
  static Future<({String name, double latitude, double longitude})?> showAddLocationByCoordinatesDialog({
    required BuildContext context,
  }) async {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit_location_alt, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Dodaj lokacijo s koordinatami')),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vnesite koordinate v WGS84 formatu (decimalne stopinje)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: latController,
                  decoration: const InputDecoration(
                    labelText: 'Zemljepisna širina (Lat)',
                    hintText: 'npr. 46.0569',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.north),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vnesite širino';
                    }
                    final lat = double.tryParse(value.trim().replaceAll(',', '.'));
                    if (lat == null) {
                      return 'Neveljavna številka';
                    }
                    if (lat < -90 || lat > 90) {
                      return 'Širina mora biti med -90 in 90';
                    }
                    // Slovenia bounds check (rough)
                    if (lat < 45.4 || lat > 46.9) {
                      return 'Lokacija ni v Sloveniji (45.4-46.9)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lngController,
                  decoration: const InputDecoration(
                    labelText: 'Zemljepisna dolžina (Lng)',
                    hintText: 'npr. 14.5058',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.east),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vnesite dolžino';
                    }
                    final lng = double.tryParse(value.trim().replaceAll(',', '.'));
                    if (lng == null) {
                      return 'Neveljavna številka';
                    }
                    if (lng < -180 || lng > 180) {
                      return 'Dolžina mora biti med -180 in 180';
                    }
                    // Slovenia bounds check (rough)
                    if (lng < 13.3 || lng > 16.6) {
                      return 'Lokacija ni v Sloveniji (13.3-16.6)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ime lokacije',
                    hintText: 'Vnesite ime za to lokacijo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vnesite ime';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Prekliči'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            icon: const Icon(Icons.add_location),
            label: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (result == true) {
      final lat = double.parse(latController.text.trim().replaceAll(',', '.'));
      final lng = double.parse(lngController.text.trim().replaceAll(',', '.'));
      return (name: nameController.text.trim(), latitude: lat, longitude: lng);
    }
    return null;
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

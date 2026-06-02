import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_location.dart';
import '../services/cadastral_service.dart';
import '../services/owner_lookup_service.dart';

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

  /// The parcel info card (header + KO + area + owner) shown when importing a
  /// cadastral parcel. Extracted so both the map's non-modal import panel and
  /// any dialog can reuse the exact same layout. Owner is looked up locally.
  static Widget importParcelInfoCard(
    BuildContext context,
    CadastralParcel cadastralParcel,
  ) {
    final owner = OwnerLookupService.instance.lookup(
      cadastralParcel.cadastralMunicipality,
      cadastralParcel.parcelNumber,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: parcel number
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.landscape,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parcela ${cadastralParcel.parcelNumber}',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Katastrska parcela',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(
            height: 24,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          _detailRow(
            context,
            Icons.location_city,
            'Katastrska občina',
            owner?.koName != null
                ? '${owner!.koName} (${cadastralParcel.cadastralMunicipality})'
                : cadastralParcel.cadastralMunicipality.toString(),
          ),
          _detailRow(
            context,
            Icons.straighten,
            'Površina',
            cadastralParcel.formattedArea,
          ),
          if (owner != null)
            _detailRow(
              context,
              Icons.person,
              'Lastnik',
              owner.displayOwners,
              secondary: owner.address,
            ),
        ],
      ),
    );
  }

  /// One attribute row: leading icon, with a muted label above the value
  /// (and an optional muted secondary line below, e.g. owner address). The
  /// value gets full width so long names/KO labels don't wrap awkwardly.
  static Widget _detailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    String? secondary,
  }) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (secondary != null && secondary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

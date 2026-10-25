import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/l10n.dart';
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
            Expanded(child: Text(context.l10n.mapwAddLocationTitle)),
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
                  context.l10n.mapwAddLocationHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: latController,
                  decoration: InputDecoration(
                    labelText: context.l10n.mapwLatLabel,
                    hintText: context.l10n.mapwLatExample,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.north),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.mapwEnterLat;
                    }
                    final lat = double.tryParse(value.trim().replaceAll(',', '.'));
                    if (lat == null) {
                      return context.l10n.mapwInvalidNumber;
                    }
                    if (lat < -90 || lat > 90) {
                      return context.l10n.mapwLatRange;
                    }
                    // Slovenia bounds check (rough)
                    if (lat < 45.4 || lat > 46.9) {
                      return context.l10n.mapwLatNotInSlovenia;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lngController,
                  decoration: InputDecoration(
                    labelText: context.l10n.mapwLngLabel,
                    hintText: context.l10n.mapwLngExample,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.east),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.mapwEnterLng;
                    }
                    final lng = double.tryParse(value.trim().replaceAll(',', '.'));
                    if (lng == null) {
                      return context.l10n.mapwInvalidNumber;
                    }
                    if (lng < -180 || lng > 180) {
                      return context.l10n.mapwLngRange;
                    }
                    // Slovenia bounds check (rough)
                    if (lng < 13.3 || lng > 16.6) {
                      return context.l10n.mapwLngNotInSlovenia;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.mapwLocationNameLabel,
                    hintText: context.l10n.mapwLocationNameHint,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.mapwEnterName;
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
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            icon: const Icon(Icons.add_location),
            label: Text(context.l10n.commonAdd),
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
            Text(context.l10n.mapwMarkFellingTitle),
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
              decoration: InputDecoration(
                labelText: context.l10n.mapwTreeDescLabel,
                hintText: context.l10n.mapwTreeDescHint,
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
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton.icon(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.mapwEnterDescription)),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            icon: const Icon(Icons.carpenter),
            label: Text(context.l10n.mapwMarkAction),
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
        title: Text(context.l10n.mapwDeleteLocationTitle),
        content: Text(context.l10n.mapwDeleteLocationSure(location.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.commonDelete),
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
            Expanded(child: Text(context.l10n.mapwAddLocationByCoordsTitle)),
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
                  context.l10n.mapwEnterWgs84Hint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: latController,
                  decoration: InputDecoration(
                    labelText: context.l10n.mapwLatLabel,
                    hintText: context.l10n.mapwLatExample,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.north),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.mapwEnterLat;
                    }
                    final lat = double.tryParse(value.trim().replaceAll(',', '.'));
                    if (lat == null) {
                      return context.l10n.mapwInvalidNumber;
                    }
                    if (lat < -90 || lat > 90) {
                      return context.l10n.mapwLatRange;
                    }
                    // Slovenia bounds check (rough)
                    if (lat < 45.4 || lat > 46.9) {
                      return context.l10n.mapwLatNotInSlovenia;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lngController,
                  decoration: InputDecoration(
                    labelText: context.l10n.mapwLngLabel,
                    hintText: context.l10n.mapwLngExample,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.east),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.mapwEnterLng;
                    }
                    final lng = double.tryParse(value.trim().replaceAll(',', '.'));
                    if (lng == null) {
                      return context.l10n.mapwInvalidNumber;
                    }
                    if (lng < -180 || lng > 180) {
                      return context.l10n.mapwLngRange;
                    }
                    // Slovenia bounds check (rough)
                    if (lng < 13.3 || lng > 16.6) {
                      return context.l10n.mapwLngNotInSlovenia;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.mapwLocationNameLabel,
                    hintText: context.l10n.mapwLocationNameHint,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.mapwEnterName;
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
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            icon: const Icon(Icons.add_location),
            label: Text(context.l10n.commonAdd),
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
        title: Text(context.l10n.mapwRenameLocationTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.l10n.mapwNameLabel,
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.commonSave),
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
                      context.l10n.mapwParcelTitle(cadastralParcel.parcelNumber.toString()),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      context.l10n.mapwCadastralParcel,
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
            context.l10n.mapwCadastralMunicipality,
            owner?.koName != null
                ? '${owner!.koName} (${cadastralParcel.cadastralMunicipality})'
                : cadastralParcel.cadastralMunicipality.toString(),
          ),
          _detailRow(
            context,
            Icons.straighten,
            context.l10n.mapwArea,
            cadastralParcel.formattedArea,
          ),
          if (owner != null)
            _detailRow(
              context,
              Icons.person,
              context.l10n.mapwOwner,
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

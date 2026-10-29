import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/l10n.dart';
import '../models/map_location.dart';
import '../services/cadastral_service.dart';
import '../services/owner_lookup_service.dart';
import '../services/si_valuation_service.dart';
import 'auction_sheet.dart';
import 'navigate_to_sheet.dart';
import 'owner_list.dart';
import 'parcel_info_widgets.dart';
import 'sheet_parts.dart';

/// Helper class for map-related dialogs
class MapDialogs {
  MapDialogs._(); // Private constructor - static methods only

  /// Sheet for naming something placed at [position] from the long-press
  /// quick view: the shared header (back returns to the quick view through
  /// [onBack]), one text field and a full-width action. Returns the trimmed
  /// text, or null when backed out or closed.
  static Future<String?> _showNameSheet({
    required BuildContext context,
    required LatLng position,
    required IconData icon,
    required Color color,
    required String title,
    required String label,
    required String hint,
    required String emptyError,
    required IconData actionIcon,
    required String actionLabel,
    VoidCallback? onBack,
  }) async {
    final controller = TextEditingController();
    var backedOut = false;
    final name = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setState) {
            void submit() {
              final text = controller.text.trim();
              if (text.isEmpty) {
                setState(() => error = emptyError);
                return;
              }
              Navigator.of(context).pop(text);
            }

            return Padding(
              // Stay above the keyboard.
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SheetHandle(),
                      SheetHeader(
                        icon: icon,
                        color: color,
                        title: title,
                        subtitle: NavigateToSheet.coordinates(position),
                        onBack: () {
                          backedOut = true;
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: label,
                          hintText: hint,
                          errorText: error,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Icon(actionIcon),
                        label: Text(actionLabel),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (backedOut) onBack?.call();
    return name;
  }

  /// Name a new point at [position]. Returns the name and coordinates, or
  /// null when cancelled.
  static Future<({String name, double latitude, double longitude})?>
      showAddLocationDialog({
    required BuildContext context,
    required LatLng position,
    VoidCallback? onBack,
  }) async {
    final name = await _showNameSheet(
      context: context,
      position: position,
      icon: Icons.add_location_alt,
      color: Colors.red,
      title: context.l10n.mapwAddLocationTitle,
      label: context.l10n.mapwLocationNameLabel,
      hint: context.l10n.mapwLocationNameHint,
      emptyError: context.l10n.mapwEnterName,
      actionIcon: Icons.add_location,
      actionLabel: context.l10n.commonAdd,
      onBack: onBack,
    );
    if (name == null) return null;
    return (
      name: name,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Mark a tree to be cut at [position]. Returns its description, or null
  /// when cancelled.
  static Future<String?> showAddSecnjaDialog({
    required BuildContext context,
    required LatLng position,
    VoidCallback? onBack,
  }) {
    return _showNameSheet(
      context: context,
      position: position,
      icon: Icons.carpenter,
      color: Colors.deepOrange,
      title: context.l10n.mapwMarkFellingTitle,
      label: context.l10n.mapwTreeDescLabel,
      hint: context.l10n.mapwTreeDescHint,
      emptyError: context.l10n.mapwEnterDescription,
      actionIcon: Icons.carpenter,
      actionLabel: context.l10n.mapwMarkAction,
      onBack: onBack,
    );
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
                    if (lat < 42.3 || lat > 46.9) {
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
                    if (lng < 13.3 || lng > 19.5) {
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

  /// Details of a parcel about to be imported, laid out like the long-press
  /// quick view: one line each for the parcel ([title]), its KO, the area, the owners (tap for all) and,
  /// for Slovenian parcels, the GURS value (tap for the breakdown).
  static Widget importParcelDetails(
    BuildContext context,
    CadastralParcel cadastralParcel, {
    required String title,
    required String koLine,
  }) {
    final ko = cadastralParcel.cadastralMunicipality;
    final owner = OwnerLookupService.instance.lookup(
      ko,
      cadastralParcel.parcelNumber,
    );
    final manyOwners = owner != null && owner.owners.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoLine(context, Icons.terrain, title, bold: true),
        _infoLine(context, Icons.location_city, koLine),
        _infoLine(context, Icons.straighten, cadastralParcel.formattedArea),
        if (owner != null)
          _infoLine(
            context,
            Icons.person,
            ownerSummary(owner.owners),
            onTap: manyOwners
                ? () => OwnersSheet.show(
                      context,
                      owners: owner.owners,
                      info: owner,
                    )
                : null,
          ),
        if (SiValuationService.covers(ko))
          FutureBuilder<ParcelValuation?>(
            future: SiValuationService.instance.lookup(
              ko,
              cadastralParcel.parcelNumber,
            ),
            builder: (context, snapshot) {
              final v = snapshot.data;
              if (v == null || v.isUnvalued) return const SizedBox.shrink();
              return _infoLine(
                context,
                Icons.euro,
                valuationSummary(context, v),
                onTap: () => ParcelValuationCard.show(context, v),
              );
            },
          ),
        if (SiValuationService.covers(ko))
          ParcelAuctionLine(
            sifko: ko,
            parcela: cadastralParcel.parcelNumber,
          ),
      ],
    );
  }

  /// One quick-view line: an accent icon and the text, with a chevron when
  /// it opens more.
  static Widget _infoLine(
    BuildContext context,
    IconData icon,
    String text, {
    VoidCallback? onTap,
    bool bold = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: bold
                    ? Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )
                    : Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }

}

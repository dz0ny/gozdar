import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/parcel.dart';
import '../services/public_parcel_settings.dart';

/// Top-level groups in the long-press menu. Tapping a group drills into its
/// sub-icons (replacing the row, with a back arrow to return).
enum _MenuSection { add, measure }

/// Modal bottom sheet shown on map long press with location-based actions.
///
/// Rendered as a sheet (instead of a popup floating over the map tiles) so the
/// options stay readable regardless of the underlying imagery.
///
/// The sheet is a small drill-down menu: the top level shows grouped icons
/// (Dodaj, Merjenje) plus direct actions (Uvozi/Parcela,
/// Natisni, Mejniki); tapping a group replaces the row with its sub-icons.
class MapLongPressMenu extends StatefulWidget {
  final VoidCallback onAddLocation;
  final VoidCallback onAddLog;
  final VoidCallback onAddSecnja;

  /// Import / show info for the parcel under the press (labelled "Uvozi").
  final VoidCallback onImportParcel;
  final VoidCallback? onViewParcel;

  final Parcel? existingParcel;

  /// Concise info about the parcel under the press, shown as a compact header.
  /// [parcelTitle] is the main line (e.g. "Parc. 123/4 • KO 1234 Ime"),
  /// [parcelSubtitle] a smaller line (e.g. the area "1.234 m²"), [parcelOwner]
  /// the owner(s) and [parcelAddress] their address, each on its own line. All
  /// null when no parcel sits under the long-press point (or the value is
  /// unknown).
  final String? parcelTitle;
  final String? parcelSubtitle;
  final String? parcelOwner;
  final String? parcelAddress;

  /// Public-owner category when the parcel is publicly owned/managed (javna
  /// parcela), shown as a coloured badge. Null for private parcels.
  final PublicOwnerCategory? parcelPublicCategory;

  /// Start a distance / area measurement from the long-press menu.
  final VoidCallback onMeasureDistance;
  final VoidCallback onMeasureArea;

  /// Whether a specific offline parcel sits under the long-press point — gates
  /// the (per-parcel) mejniki toggle.
  final bool mejnikiAvailable;
  final bool showMejniki;
  final ValueChanged<bool> onToggleMejniki;

  /// Closes the (non-modal) sheet. Called by actions before they run.
  final VoidCallback onClose;

  const MapLongPressMenu({
    super.key,
    required this.onAddLocation,
    required this.onAddLog,
    required this.onAddSecnja,
    required this.onImportParcel,
    this.onViewParcel,
    this.existingParcel,
    this.parcelTitle,
    this.parcelSubtitle,
    this.parcelOwner,
    this.parcelAddress,
    this.parcelPublicCategory,
    required this.onMeasureDistance,
    required this.onMeasureArea,
    required this.mejnikiAvailable,
    required this.showMejniki,
    required this.onToggleMejniki,
    required this.onClose,
  });

  /// Currently open sheet, so a new long-press replaces it instead of stacking.
  static PersistentBottomSheetController? _open;

  /// Close the open long-press sheet, if any (e.g. when switching tabs).
  static void closeOpen() {
    _open?.close();
    _open = null;
  }

  /// Present the action menu as a *non-modal* bottom sheet: no scrim and the map
  /// behind stays pannable. Returns a future that completes when it closes.
  static Future<void> show(
    BuildContext context, {
    required LatLng mapPosition,
    Parcel? existingParcel,
    required VoidCallback onAddLocation,
    required VoidCallback onAddLog,
    required VoidCallback onAddSecnja,
    required VoidCallback onImportParcel,
    VoidCallback? onViewParcel,
    String? parcelTitle,
    String? parcelSubtitle,
    String? parcelOwner,
    String? parcelAddress,
    PublicOwnerCategory? parcelPublicCategory,
    required VoidCallback onMeasureDistance,
    required VoidCallback onMeasureArea,
    required bool mejnikiAvailable,
    required bool showMejniki,
    required ValueChanged<bool> onToggleMejniki,
  }) async {
    _open?.close();
    late final PersistentBottomSheetController controller;
    controller = Scaffold.of(context).showBottomSheet(
      showDragHandle: true,
      // Strip the inherited bottom safe-area inset: the sheet sits above the
      // app's nav bar (which already clears the home indicator), so reserving it
      // again just leaves dead space under the actions.
      (ctx) => MediaQuery.removePadding(
        context: ctx,
        removeBottom: true,
        child: MapLongPressMenu(
          existingParcel: existingParcel,
          onAddLocation: onAddLocation,
          onAddLog: onAddLog,
          onAddSecnja: onAddSecnja,
          onImportParcel: onImportParcel,
          onViewParcel: onViewParcel,
          parcelTitle: parcelTitle,
          parcelSubtitle: parcelSubtitle,
          parcelOwner: parcelOwner,
          parcelAddress: parcelAddress,
          parcelPublicCategory: parcelPublicCategory,
          onMeasureDistance: onMeasureDistance,
          onMeasureArea: onMeasureArea,
          mejnikiAvailable: mejnikiAvailable,
          showMejniki: showMejniki,
          onToggleMejniki: onToggleMejniki,
          onClose: () => controller.close(),
        ),
      ),
    );
    _open = controller;
    await controller.closed;
    if (identical(_open, controller)) _open = null;
  }

  @override
  State<MapLongPressMenu> createState() => _MapLongPressMenuState();
}

class _MapLongPressMenuState extends State<MapLongPressMenu> {
  /// Open drill-down group, or null at the top level.
  _MenuSection? _section;

  /// Compact icon tile: an icon over a short label, sized for a toolbar grid.
  Widget _tile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 80,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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

  /// Leaf action: closes the sheet, then runs [onTap].
  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _tile(
      icon: icon,
      label: label,
      color: color,
      onTap: () {
        widget.onClose();
        onTap();
      },
    );
  }

  /// Group entry: drills into [section] (the sheet stays open).
  Widget _group({
    required IconData icon,
    required String label,
    required Color color,
    required _MenuSection section,
  }) {
    return _tile(
      icon: icon,
      label: label,
      color: color,
      onTap: () => setState(() => _section = section),
    );
  }

  Widget _topLevel() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        _group(
          icon: Icons.add_circle_outline,
          label: 'Dodaj',
          color: Colors.red,
          section: _MenuSection.add,
        ),
        _group(
          icon: Icons.straighten,
          label: 'Merjenje',
          color: Colors.teal,
          section: _MenuSection.measure,
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
            icon: Icons.download,
            label: 'Uvozi',
            color: Colors.blue,
            onTap: widget.onImportParcel,
          ),
      ],
    );
  }

  /// Compact one/two-line header with basic info about the parcel under the
  /// press. Kept deliberately small so the sheet stays low.
  Widget _parcelInfoHeader() {
    final cs = Theme.of(context).colorScheme;
    final hasOwner =
        widget.parcelOwner != null && widget.parcelOwner!.isNotEmpty;
    final hasAddress =
        widget.parcelAddress != null && widget.parcelAddress!.isNotEmpty;
    final cat = widget.parcelPublicCategory;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.terrain, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.parcelTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.parcelSubtitle != null &&
                        widget.parcelSubtitle!.isNotEmpty)
                      Text(
                        widget.parcelSubtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (hasOwner)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.person, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.parcelOwner!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (hasAddress)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.home_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.parcelAddress!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (cat != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cat.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Javna parcela • ${cat.label}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cat.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _addSection() {
    return Wrap(
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
      ],
    );
  }

  Widget _measureSection() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
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
        if (widget.mejnikiAvailable)
          _action(
            icon: Icons.scatter_plot,
            label: 'Mejniki',
            color: widget.showMejniki ? Colors.orange : Colors.green,
            onTap: () => widget.onToggleMejniki(!widget.showMejniki),
          ),
      ],
    );
  }

  String _sectionTitle(_MenuSection section) {
    switch (section) {
      case _MenuSection.add:
        return 'Dodaj';
      case _MenuSection.measure:
        return 'Merjenje';
    }
  }

  Widget _sectionContent(_MenuSection section) {
    switch (section) {
      case _MenuSection.add:
        return _addSection();
      case _MenuSection.measure:
        return _measureSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    // No bottom safe-area inset: the sheet sits above the nav bar, which already
    // accounts for the home indicator — adding it here leaves dead space.
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: section == null
              ? [
                  if (widget.parcelTitle != null) _parcelInfoHeader(),
                  _topLevel(),
                ]
              : [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Nazaj',
                        onPressed: () => setState(() => _section = null),
                      ),
                      Text(
                        _sectionTitle(section),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: _sectionContent(section),
                  ),
                ],
        ),
      ),
    );
  }
}

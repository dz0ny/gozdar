import 'package:flutter/material.dart';
import '../models/parcel.dart';
import '../services/cadastral_service.dart';
import '../services/ko_locator.dart';
import '../services/owner_lookup_service.dart';
import 'parcel_silhouette.dart';

/// Compact details of a parcel found by search, with one action (import or
/// open). Shown as a non-modal sheet, so the map behind it stays usable and
/// the found parcel's outline remains visible.
class ParcelFoundSheet extends StatelessWidget {
  final WfsParcel wfsParcel;
  final Parcel? existingParcel;

  /// Close button.
  final VoidCallback onHide;

  /// Primary button (import a new parcel / open an existing one).
  final VoidCallback onAction;

  const ParcelFoundSheet({
    super.key,
    required this.wfsParcel,
    required this.existingParcel,
    required this.onHide,
    required this.onAction,
  });

  /// Show the sheet anchored to [scaffold] without a backdrop. The returned
  /// controller's `closed` future completes however the sheet goes away.
  static PersistentBottomSheetController show({
    required ScaffoldState scaffold,
    required WfsParcel wfsParcel,
    required Parcel? existingParcel,
    required VoidCallback onHide,
    required VoidCallback onAction,
  }) {
    late final PersistentBottomSheetController controller;
    controller = scaffold.showBottomSheet(
      (context) => ParcelFoundSheet(
        wfsParcel: wfsParcel,
        existingParcel: existingParcel,
        onHide: () {
          controller.close();
          onHide();
        },
        onAction: () {
          controller.close();
          onAction();
        },
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: false,
    );
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sifko = int.tryParse(wfsParcel.koNumber);
    final ownerInfo = OwnerLookupService.instance.lookup(
      sifko,
      wfsParcel.parcelNumber,
    );
    final ko = KoLocator.instance.bySifko(sifko);
    final koLabel = ko?.label ??
        (ownerInfo?.koName != null
            ? '${ownerInfo!.koName} (${wfsParcel.koNumber})'
            : wfsParcel.koNumber);
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ParcelSilhouette(
                    polygon: wfsParcel.polygon,
                    size: 52,
                    fillColor: cs.primary.withValues(alpha: 0.3),
                    strokeColor: cs.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parcela ${wfsParcel.label}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('KO $koLabel', style: muted),
                      Text(wfsParcel.formattedArea, style: muted),
                      if (ownerInfo != null)
                        Text(
                          ownerInfo.address != null
                              ? '${ownerInfo.displayOwners} • ${ownerInfo.address}'
                              : ownerInfo.displayOwners,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Skrij',
                  icon: const Icon(Icons.close),
                  onPressed: onHide,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: Icon(
                  existingParcel != null ? Icons.visibility : Icons.download,
                ),
                label: Text(
                  existingParcel != null ? 'Odpri parcelo' : 'Uvozi parcelo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

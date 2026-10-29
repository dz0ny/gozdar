import 'package:flutter/material.dart';
import '../models/parcel.dart';
import '../services/cadastral_service.dart';
import '../services/hr_owner_service.dart';
import 'auction_sheet.dart';
import 'owner_list.dart';
import '../services/ko_locator.dart';
import '../services/owner_lookup_service.dart';
import '../services/si_valuation_service.dart';
import 'parcel_info_widgets.dart';
import 'parcel_silhouette.dart';
import '../l10n/l10n.dart';

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

  /// First owner and how many more, the address below; tap lists everyone.
  Widget _ownerText(OwnerInfo info, ThemeData theme) => Builder(
        builder: (context) {
          final many = info.owners.length > 1;
          return InkWell(
            onTap: many
                ? () => OwnersSheet.show(
                      context,
                      owners: info.owners,
                      info: info,
                    )
                : null,
            borderRadius: BorderRadius.circular(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ownerSummary(info.owners),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    if (many)
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
                if (info.address != null)
                  Text(
                    info.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        },
      );

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
                        context.l10n.parcelFoundTitle(wfsParcel.label),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(context.l10n.parcelFoundKo(koLabel), style: muted),
                      Text(wfsParcel.formattedArea, style: muted),
                      if (ownerInfo != null)
                        _ownerText(ownerInfo, theme)
                      else if (HrOwnerService.isCroatianKo(sifko))
                        // Croatian holders come live from the DGU cadastre.
                        FutureBuilder<OwnerInfo?>(
                          future: HrOwnerService.instance.lookup(
                            sifko!,
                            wfsParcel.parcelNumber,
                          ),
                          builder: (context, snapshot) {
                            final info = snapshot.data;
                            if (info != null) return _ownerText(info, theme);
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              context.l10n.parcelFoundOwnersLoading,
                              style: muted,
                            );
                          },
                        ),
                      if (SiValuationService.covers(sifko))
                        // GURS value, live from the valuation register.
                        FutureBuilder<ParcelValuation?>(
                          future: SiValuationService.instance.lookup(
                            sifko!,
                            wfsParcel.parcelNumber,
                          ),
                          builder: (context, snapshot) {
                            final v = snapshot.data;
                            if (v == null || v.isUnvalued) {
                              return const SizedBox.shrink();
                            }
                            return InkWell(
                              onTap: () =>
                                  ParcelValuationCard.show(context, v),
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      valuationSummary(context, v),
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: cs.primary,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (SiValuationService.covers(sifko))
                        ParcelAuctionLine(
                          sifko: sifko!,
                          parcela: wfsParcel.parcelNumber,
                          showIcon: false,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.parcelFoundHide,
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
                  existingParcel != null
                      ? context.l10n.parcelFoundOpen
                      : context.l10n.parcelFoundImport,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../services/auction_service.dart';
import 'parcel_info_widgets.dart';
import 'sheet_parts.dart';

/// "24. 11. 2027".
String auctionDate(BuildContext context, DateTime at) =>
    DateFormat('d. M. yyyy', context.l10n.localeName).format(at.toLocal());

/// "Na dražbi: 160 € · 24. 11. 2027" for one-line places.
String auctionSummary(BuildContext context, Auction a) {
  final date = auctionDate(context, a.saleStartAt);
  final price = a.startingPrice;
  return price != null
      ? context.l10n.auctionLine(euros(context, price), date)
      : context.l10n.auctionLineNoPrice(date);
}

/// One line for a parcel's auction, in the style of the lines around it;
/// opens [AuctionSheet].
class AuctionLine extends StatelessWidget {
  final Auction auction;

  /// Quick-view lines lead with an icon; the search result's lines don't.
  final bool showIcon;

  const AuctionLine({super.key, required this.auction, this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: () => AuctionSheet.show(context, auction),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (showIcon) ...[
              Icon(Icons.gavel, size: 20, color: cs.primary),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                auctionSummary(context, auction),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: showIcon
                    ? theme.textTheme.bodyLarge
                    // Like the search result's value line above it.
                    : theme.textTheme.bodyLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
            if (showIcon) const Spacer(),
            Icon(Icons.chevron_right, size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

/// [AuctionLine] for a parcel whose auctions are still being looked up;
/// nothing when it is not up for sale.
class ParcelAuctionLine extends StatelessWidget {
  final int sifko;
  final String parcela;

  final bool showIcon;

  const ParcelAuctionLine({
    super.key,
    required this.sifko,
    required this.parcela,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Auction>>(
      future: AuctionService.instance.forParcel(sifko, parcela),
      builder: (context, snapshot) {
        final list = snapshot.data;
        if (list == null || list.isEmpty) return const SizedBox.shrink();
        return AuctionLine(auction: list.first, showIcon: showIcon);
      },
    );
  }
}

/// One court auction of a parcel: the starting price in large type, the
/// appraisal, share, date and court as rows, and a link to the notice.
class AuctionSheet extends StatelessWidget {
  final Auction auction;

  const AuctionSheet({super.key, required this.auction});

  static Future<void> show(BuildContext context, Auction auction) {
    return showModalBottomSheet<void>(
      context: context,
      // Above the tab bar, not inside the tab's navigator.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AuctionSheet(auction: auction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final ko = a.koName != null ? '${a.sifko} ${a.koName}' : '${a.sifko}';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            SheetHeader(
              icon: Icons.gavel,
              title: l10n.auctionTitle,
              subtitle: '${l10n.mapTabParcelShort(a.parcela)}\n'
                  '${l10n.parcelFoundKo(ko)}',
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a.startingPrice != null) ...[
                    Text(l10n.auctionStarting, style: muted),
                    Text(
                      '${euros(context, a.startingPrice!)} €',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ],
                  if (a.isActive)
                    Text(
                      l10n.auctionActive,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.primary,
                      ),
                    ),
                  Divider(height: 32, color: cs.outlineVariant),
                  if (a.estimatedPrice != null)
                    _row(context, l10n.auctionEstimated,
                        '${euros(context, a.estimatedPrice!)} €'),
                  if (a.share != null)
                    _row(context, l10n.auctionShare, a.share!),
                  if (a.area != null)
                    _row(context, l10n.mapwArea,
                        '${euros(context, a.area!)} m²'),
                  _row(context, l10n.auctionDate,
                      auctionDate(context, a.saleStartAt)),
                  if (a.court != null) _row(context, l10n.auctionCourt, a.court!),
                  Divider(height: 32, color: cs.outlineVariant),
                  Text(l10n.auctionSource, style: muted),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => launchUrl(
                        Uri.parse(a.url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(l10n.auctionOpen),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Label left, value right-aligned, so the values line up in a column.
  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

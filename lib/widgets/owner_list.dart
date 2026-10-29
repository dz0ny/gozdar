import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../services/owner_lookup_service.dart';
import 'sheet_parts.dart';

/// "HORVAT IVA in še 11": the first owner and how many more, for one-line
/// places. A single owner is returned as is.
String ownerSummary(List<String> owners) {
  if (owners.isEmpty) return '';
  if (owners.length == 1) return owners.first;
  return L10n.current.ownerAndMore(owners.first, owners.length - 1);
}

/// Every owner of a parcel, one row each with the share and address when the
/// source has them.
class OwnersSheet extends StatelessWidget {
  final List<String> owners;
  final OwnerInfo? info;

  const OwnersSheet({super.key, required this.owners, this.info});

  /// Lists that fit on screen take only the room they need; long ones
  /// (Croatian parcels can have dozens of holders) scroll in a tall sheet.
  static const _fitLimit = 6;

  static Future<void> show(
    BuildContext context, {
    required List<String> owners,
    OwnerInfo? info,
  }) {
    final sheet = OwnersSheet(owners: owners, info: info);
    return showModalBottomSheet<void>(
      context: context,
      // Above the tab bar, not inside the tab's navigator.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => owners.length <= _fitLimit
          ? SafeArea(child: sheet._build(context, null))
          : DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (context, scrollController) =>
                  sheet._build(context, scrollController),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => _build(context, null);

  /// Fits its content without [scrollController], fills the sheet with it.
  Widget _build(BuildContext context, ScrollController? scrollController) {
    final rows = [
      for (final name in owners)
        OwnerTile(holder: info?.holder(name) ?? OwnerHolder(name)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          SheetHeader(
            icon: Icons.people_outline,
            title: context.l10n.ownersTitle(owners.length),
            subtitle: info?.koName,
          ),
          const SizedBox(height: 8),
          if (scrollController == null)
            ...rows
          else
            Expanded(
              child: ListView(controller: scrollController, children: rows),
            ),
        ],
      ),
    );
  }
}

/// One owner, like a quick-view line: an accent icon, the name with the
/// address under it, and the share on the right. Tapping searches the web
/// for the owner (company register entries, contacts).
class OwnerTile extends StatelessWidget {
  final OwnerHolder holder;

  /// Kept for callers; rows are the same size everywhere now.
  final bool dense;

  const OwnerTile({super.key, required this.holder, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => launchUrl(
        Uri.https('www.google.com', '/search', {'q': holder.name}),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Icon(Icons.person, size: 20, color: cs.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(holder.name, style: theme.textTheme.bodyLarge),
                  if (holder.address != null)
                    Text(
                      holder.address!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (holder.share != null) ...[
              const SizedBox(width: 12),
              Text(
                holder.share!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.travel_explore, size: 20, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}

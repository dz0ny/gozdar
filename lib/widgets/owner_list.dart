import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/owner_lookup_service.dart';
import '../utils/external_url.dart';
import 'sheet_parts.dart';

/// "HORVAT IVA in še 11": the first owner and how many more, for one-line
/// places. A single owner is returned as is.
String ownerSummary(List<String> owners) {
  if (owners.isEmpty) return '';
  if (owners.length == 1) return owners.first;
  return L10n.current.ownerAndMore(owners.first, owners.length - 1);
}

/// Web search text for one owner: the name and the address, when known.
/// The share says nothing to a search engine, so it stays out.
String ownerSearchQuery(OwnerHolder holder) => [
  holder.name.trim(),
  if (holder.address case final address? when address.trim().isNotEmpty)
    address.trim(),
].join(' ');

/// The web search page for one owner.
Uri ownerSearchUri(OwnerHolder holder) =>
    Uri.https('www.google.com', '/search', {'q': ownerSearchQuery(holder)});

/// The register a source names, e.g. "Zemljiška knjiga".
String ownerSourceName(BuildContext context, OwnerSource source) =>
    switch (source.kind) {
      OwnerSourceKind.landRegistry => context.l10n.ownersSourceLandRegistry,
      OwnerSourceKind.cadastre => context.l10n.ownersSourceCadastre,
    };

/// "Vir: Zemljiška knjiga" under a one-line owner summary, so the register
/// is never left out; the sheet links to it.
class OwnerSourceCaption extends StatelessWidget {
  final OwnerInfo info;

  const OwnerSourceCaption({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    if (info.sources.isEmpty) return const SizedBox.shrink();
    final names = {for (final s in info.sources) ownerSourceName(context, s)};
    final theme = Theme.of(context);
    return Text(
      context.l10n.ownersSourceLine(names.join(', ')),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// One source of the owners: the register, the ZK unit when there is one,
/// and a tap that opens the register's own page.
class OwnerSourceTile extends StatelessWidget {
  final OwnerSource source;

  const OwnerSourceTile({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final detail = switch (source.kind) {
      OwnerSourceKind.landRegistry
          when source.lrUnitNumber != null && source.place != null =>
        l10n.ownersSourceLrUnit(source.lrUnitNumber!, source.place!),
      OwnerSourceKind.landRegistry => source.place,
      OwnerSourceKind.cadastre => l10n.ownersSourceCadastreNote,
    };
    final url = source.url;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: url == null ? null : () => openExternalUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Icon(
                source.kind == OwnerSourceKind.landRegistry
                    ? Icons.menu_book_outlined
                    : Icons.map_outlined,
                size: 20,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ownerSourceName(context, source),
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (url != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Tooltip(
                  message: l10n.ownersSourceOpen,
                  child: Icon(Icons.open_in_new, size: 20, color: cs.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Every owner of a parcel, one row each with the share and address when the
/// source has them, and below them the sources with links to the register.
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
    final sources = info?.sources ?? const <OwnerSource>[];
    final theme = Theme.of(context);
    final sourceRows = [
      if (sources.isNotEmpty) ...[
        const Divider(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Text(
            context.l10n.ownersSourceTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final s in sources) OwnerSourceTile(source: s),
      ],
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
          // Below a long list, not scrolled away with it.
          ...sourceRows,
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
    return Semantics(
      link: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openExternalUrl(ownerSearchUri(holder)),
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
                child: Tooltip(
                  message: context.l10n.ownerWebSearch,
                  child: Icon(
                    Icons.travel_explore,
                    size: 20,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

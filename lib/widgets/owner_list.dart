import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/owner_lookup_service.dart';

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

  static Future<void> show(
    BuildContext context, {
    required List<String> owners,
    OwnerInfo? info,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      // Above the tab bar, not inside the tab's navigator.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: owners.length > 6 ? 0.7 : 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) => OwnersSheet(
          owners: owners,
          info: info,
        )._build(context, scrollController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _build(context, null);

  Widget _build(BuildContext context, ScrollController? scrollController) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 8),
          child: Row(
            children: [
              Icon(Icons.people_outline, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.ownersTitle(owners.length),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonClose,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: owners.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) => OwnerTile(
              holder: info?.holder(owners[i]) ?? OwnerHolder(owners[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// One owner: name, address below, share on the right.
class OwnerTile extends StatelessWidget {
  final OwnerHolder holder;
  final bool dense;

  const OwnerTile({super.key, required this.holder, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: dense,
      contentPadding: dense ? EdgeInsets.zero : null,
      leading: const Icon(Icons.person_outline),
      minLeadingWidth: dense ? 24 : null,
      title: Text(holder.name),
      subtitle: holder.address != null ? Text(holder.address!) : null,
      trailing: holder.share != null
          ? Text(
              holder.share!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}

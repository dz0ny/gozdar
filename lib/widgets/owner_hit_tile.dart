import 'package:flutter/material.dart';

import '../services/owner_lookup_service.dart';

/// One owner-search result: the parcel on the first line, then its KO, the
/// co-owners and their address, each kept to a single line so long names and
/// addresses don't turn a row into a wall of text.
class OwnerHitTile extends StatelessWidget {
  const OwnerHitTile({
    super.key,
    required this.hit,
    required this.trailing,
    this.onTap,
  });

  final OwnerSearchHit hit;
  final Widget trailing;
  final VoidCallback? onTap;

  /// "NOVAK JANEZ, NOVAK MARIJA +1" — the first two co-owners, then a count.
  static String ownersLabel(List<String> owners) {
    if (owners.isEmpty) return 'Neznan lastnik';
    if (owners.length <= 2) return owners.join(', ');
    return '${owners.take(2).join(', ')} +${owners.length - 2}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    // Own Material so the ink ripple shows inside coloured sheets.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parcela ${hit.parcela}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'KO ${hit.koLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ownersLabel(hit.owners),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (hit.address != null)
                      Text(
                        hit.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: secondary,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: Center(child: trailing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

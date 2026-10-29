import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Slim drag handle for bottom sheets. The stock one reserves a tall empty
/// strip; this one keeps the content close to the top edge.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Sheet title row: a back button, a tinted icon, the title with an optional
/// line under it and optional extra actions. Tapping outside a sheet already
/// closes everything, so the button steps back one level instead.
class SheetHeader extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// What the back button does; pops the sheet's route when null.
  final VoidCallback? onBack;

  const SheetHeader({
    super.key,
    required this.icon,
    required this.title,
    this.color,
    this.subtitle,
    this.actions = const [],
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Row(
      children: [
        IconButton(
          tooltip: context.l10n.commonBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 4),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: tint, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// Big action tile: a large icon on a tinted square over its label. Put
/// several in a [SheetTileRow] so they share the sheet's width.
class SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  /// Null shows the tile dimmed and not tappable.
  final VoidCallback? onTap;

  const SheetTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
    return onTap == null ? Opacity(opacity: 0.4, child: tile) : tile;
  }
}

/// Tiles side by side, each an equal share of the width.
class SheetTileRow extends StatelessWidget {
  final List<Widget> tiles;

  const SheetTileRow(this.tiles, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final t in tiles) Expanded(child: t)],
    );
  }
}

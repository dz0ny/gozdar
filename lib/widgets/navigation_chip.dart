import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';
import '../models/navigation_target.dart';
import '../utils/formats.dart';
import 'location_tracker.dart';

/// Shown over the map while a navigation target is set: the target's name
/// and how far it is. Tapping it opens the compass; the ✕ ends navigation.
/// Listens to [fix] itself, so the distance updates without rebuilding the
/// map tab.
class NavigationChip extends StatelessWidget {
  const NavigationChip({
    super.key,
    required this.target,
    required this.fix,
    required this.onOpenCompass,
    required this.onEnd,
  });

  final NavigationTarget target;
  final ValueListenable<UserFix?> fix;
  final VoidCallback onOpenCompass;
  final VoidCallback onEnd;

  static const _distance = Distance();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InkWell(
              onTap: onOpenCompass,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.navigation,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        target.name,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ValueListenableBuilder<UserFix?>(
                      valueListenable: fix,
                      builder: (context, fix, _) {
                        if (fix == null) return const SizedBox.shrink();
                        final meters = _distance.as(
                          LengthUnit.Meter,
                          fix.position,
                          target.location,
                        );
                        return Text(
                          ' · ${Fmt.distance(meters)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.mapwEndNavigation,
            onPressed: onEnd,
          ),
        ],
      ),
    );
  }
}

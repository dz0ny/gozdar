import 'package:material_ui/material_ui.dart';

import '../models/log_entry.dart';
import '../theme/motion.dart';
import '../utils/formats.dart';

class LogCard extends StatelessWidget {
  final LogEntry logEntry;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  /// Marks the log added last, so it stands out in a long list.
  final bool highlighted;

  const LogCard({
    super.key,
    required this.logEntry,
    required this.onTap,
    required this.onDismissed,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('log_${logEntry.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.short),
          decoration: BoxDecoration(
            color: highlighted
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            border: Border(
              left: BorderSide(
                width: 4,
                color: highlighted
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          // Volume and dimensions on the left, species on the right (capped);
          // both truncate with an ellipsis so large text or long species names
          // don't overflow the row.
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: Fmt.m3(logEntry.volume),
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (logEntry.diameter != null && logEntry.length != null)
                        TextSpan(
                          text:
                              '   Ø ${Fmt.num(logEntry.diameter!, 0)} cm × ${Fmt.num(logEntry.length!, 1)} m',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey[400]),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (logEntry.species != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.forest, size: 18, color: Colors.green[600]),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    logEntry.species!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.green[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              if (logEntry.hasLocation) ...[
                const SizedBox(width: 8),
                Icon(Icons.location_on, color: Colors.blue[300], size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../utils/formats.dart';

class LogCard extends StatelessWidget {
  final LogEntry logEntry;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const LogCard({
    super.key,
    required this.logEntry,
    required this.onTap,
    required this.onDismissed,
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
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (logEntry.diameter != null && logEntry.length != null)
                        TextSpan(
                          text:
                              '   Ø ${Fmt.num(logEntry.diameter!, 0)} cm × ${Fmt.num(logEntry.length!, 1)} m',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[400],
                              ),
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

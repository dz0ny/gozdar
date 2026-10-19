import 'package:flutter/material.dart';
import '../models/log_entry.dart';

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
          child: Row(
            children: [
              Text(
                '${logEntry.volume.toStringAsFixed(2)} m³',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (logEntry.diameter != null && logEntry.length != null) ...[
                const SizedBox(width: 10),
                Text(
                  'Ø ${logEntry.diameter!.toStringAsFixed(0)} × ${logEntry.length!.toStringAsFixed(1)} m',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
              const Spacer(),
              if (logEntry.species != null) ...[
                Icon(Icons.forest, size: 18, color: Colors.green[600]),
                const SizedBox(width: 4),
                Text(
                  logEntry.species!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
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

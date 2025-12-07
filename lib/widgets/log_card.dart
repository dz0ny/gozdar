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
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${logEntry.volume.toStringAsFixed(3)} m³',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (logEntry.diameter != null && logEntry.length != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              'Ø ${logEntry.diameter!.toStringAsFixed(0)} × ${logEntry.length!.toStringAsFixed(1)} m',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ],
                      ),
                      if (logEntry.species != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.forest,
                              size: 14,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              logEntry.species!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (logEntry.hasLocation)
                  Icon(
                    Icons.location_on,
                    color: Colors.blue[300],
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

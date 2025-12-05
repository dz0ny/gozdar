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
                Text(
                  '${logEntry.volume.toStringAsFixed(3)} m³',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 12),
                if (logEntry.diameter != null && logEntry.length != null)
                  Text(
                    'Ø ${logEntry.diameter!.toStringAsFixed(0)} × ${logEntry.length!.toStringAsFixed(1)} m',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                const Spacer(),
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

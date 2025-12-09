import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/log_entry.dart';
import '../models/map_location.dart';

/// Card displaying logs within a parcel
class ParcelLogsCard extends StatelessWidget {
  final List<LogEntry> logs;
  final double totalVolume;
  final Function(LatLng point, String name) onNavigateToPoint;

  const ParcelLogsCard({
    super.key,
    required this.logs,
    required this.totalVolume,
    required this.onNavigateToPoint,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.inventory_2, color: Colors.brown),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hlodovina na parceli (${logs.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${totalVolume.toStringAsFixed(2)} m³',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[700],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length > 5 ? 5 : logs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.brown.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.circle,
                    color: Colors.brown,
                    size: 20,
                  ),
                ),
                title: Text(
                  '${log.volume.toStringAsFixed(4)} m³',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Row(
                  children: [
                    if (log.diameter != null && log.length != null)
                      Text(
                        'Ø ${log.diameter!.toStringAsFixed(0)} cm × ${log.length!.toStringAsFixed(1)} m',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      )
                    else
                      Text(
                        'Ročni vnos',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    if (log.hasLocation) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.gps_fixed,
                              size: 12,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'GPS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: log.hasLocation
                    ? IconButton(
                        icon: const Icon(Icons.navigation, color: Colors.blue),
                        tooltip: 'Navigiraj',
                        onPressed: () => onNavigateToPoint(
                          LatLng(log.latitude!, log.longitude!),
                          'Hlod ${log.id}',
                        ),
                      )
                    : null,
              );
            },
          ),
          if (logs.length > 5)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  '... in še ${logs.length - 5} hlodov',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card displaying locations within a parcel
class ParcelLocationsCard extends StatelessWidget {
  final List<MapLocation> locations;
  final Function(LatLng point, String name) onNavigateToPoint;

  const ParcelLocationsCard({
    super.key,
    required this.locations,
    required this.onNavigateToPoint,
  });

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Shranjene tocke (${locations.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: locations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final location = locations[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.place,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(location.name),
                subtitle: Text(
                  '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.navigation, color: Colors.blue),
                  tooltip: 'Navigiraj',
                  onPressed: () => onNavigateToPoint(
                    LatLng(location.latitude, location.longitude),
                    location.name,
                  ),
                ),
                onTap: () => onNavigateToPoint(
                  LatLng(location.latitude, location.longitude),
                  location.name,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Card displaying trees marked for cutting within a parcel
class ParcelSecnjaCard extends StatelessWidget {
  final List<MapLocation> secnja;
  final Function(LatLng point, String name) onNavigateToPoint;

  const ParcelSecnjaCard({
    super.key,
    required this.secnja,
    required this.onNavigateToPoint,
  });

  @override
  Widget build(BuildContext context) {
    if (secnja.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.carpenter, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text(
                  'Sečnja (${secnja.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: secnja.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final location = secnja[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.carpenter,
                    color: Colors.deepOrange,
                    size: 20,
                  ),
                ),
                title: Text(location.name),
                subtitle: Text(
                  '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.navigation, color: Colors.blue),
                  tooltip: 'Navigiraj',
                  onPressed: () => onNavigateToPoint(
                    LatLng(location.latitude, location.longitude),
                    location.name,
                  ),
                ),
                onTap: () => onNavigateToPoint(
                  LatLng(location.latitude, location.longitude),
                  location.name,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

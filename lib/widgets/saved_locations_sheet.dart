import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_location.dart';
import '../models/log_entry.dart';
import '../models/parcel.dart';
import '../models/navigation_target.dart';

/// Bottom sheet displaying saved locations and logs with navigation and edit options
class SavedLocationsSheet extends StatelessWidget {
  final List<MapLocation> locations;
  final List<LogEntry> logs;
  final List<Parcel> parcels;
  final void Function(NavigationTarget target) onNavigate;
  final void Function(MapLocation location) onEdit;
  final void Function(MapLocation location) onDelete;
  final void Function()? onAddByCoordinates;

  const SavedLocationsSheet({
    super.key,
    required this.locations,
    this.logs = const [],
    this.parcels = const [],
    required this.onNavigate,
    required this.onEdit,
    required this.onDelete,
    this.onAddByCoordinates,
  });

  /// Show the saved locations sheet as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required List<MapLocation> locations,
    List<LogEntry> logs = const [],
    List<Parcel> parcels = const [],
    required void Function(NavigationTarget target) onNavigate,
    required void Function(MapLocation location) onEdit,
    required void Function(MapLocation location) onDelete,
    void Function()? onAddByCoordinates,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _ContentWidget(
            scrollController: scrollController,
            locations: locations,
            logs: logs,
            parcels: parcels,
            onNavigate: onNavigate,
            onEdit: onEdit,
            onDelete: onDelete,
            onAddByCoordinates: onAddByCoordinates,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ContentWidget(
      scrollController: ScrollController(),
      locations: locations,
      logs: logs,
      parcels: parcels,
      onNavigate: onNavigate,
      onEdit: onEdit,
      onDelete: onDelete,
      onAddByCoordinates: onAddByCoordinates,
    );
  }
}

class _ContentWidget extends StatelessWidget {
  final ScrollController scrollController;
  final List<MapLocation> locations;
  final List<LogEntry> logs;
  final List<Parcel> parcels;
  final void Function(NavigationTarget target) onNavigate;
  final void Function(MapLocation location) onEdit;
  final void Function(MapLocation location) onDelete;
  final void Function()? onAddByCoordinates;

  const _ContentWidget({
    required this.scrollController,
    required this.locations,
    required this.logs,
    required this.parcels,
    required this.onNavigate,
    required this.onEdit,
    required this.onDelete,
    this.onAddByCoordinates,
  });

  /// Find containing parcel for a point
  String? _findParcelName(double lat, double lng) {
    for (final parcel in parcels) {
      if (parcel.containsPoint(LatLng(lat, lng))) {
        return parcel.name;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Filter logs with location
    final geolocatedLogs = logs.where((log) => log.hasLocation).toList();
    final totalCount = locations.length + geolocatedLogs.length;

    return Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.place, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Shranjene lokacije',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  '$totalCount',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (onAddByCoordinates != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_location_alt),
                    tooltip: 'Dodaj s koordinatami',
                    onPressed: () {
                      Navigator.pop(context);
                      onAddByCoordinates!();
                    },
                  ),
                ],
              ],
            ),
          ),
          // List
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // Locations section (non-sečnja)
                if (locations.where((l) => !l.isSecnja).isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.location_on,
                    color: Colors.orange,
                    title: 'Točke',
                    count: locations.where((l) => !l.isSecnja).length,
                  ),
                  ...locations.where((l) => !l.isSecnja).map((location) {
                    final parcelName = _findParcelName(
                      location.latitude,
                      location.longitude,
                    );
                    return _LocationListTile(
                      location: location,
                      parcelName: parcelName,
                      onNavigate: onNavigate,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    );
                  }),
                ],
                // Sečnja section
                if (locations.any((l) => l.isSecnja)) ...[
                  _SectionHeader(
                    icon: Icons.carpenter,
                    color: Colors.deepOrange,
                    title: 'Sečnja',
                    count: locations.where((l) => l.isSecnja).length,
                  ),
                  ...locations.where((l) => l.isSecnja).map((location) {
                    final parcelName = _findParcelName(
                      location.latitude,
                      location.longitude,
                    );
                    return _LocationListTile(
                      location: location,
                      parcelName: parcelName,
                      onNavigate: onNavigate,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    );
                  }),
                ],
                // Logs section
                if (geolocatedLogs.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.forest,
                    color: Colors.brown,
                    title: 'Hlodovina',
                    count: geolocatedLogs.length,
                  ),
                  ...geolocatedLogs.map((log) {
                    final parcelName = _findParcelName(
                      log.latitude!,
                      log.longitude!,
                    );
                    return _LogListTile(
                      log: log,
                      parcelName: parcelName,
                      onNavigate: onNavigate,
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationListTile extends StatelessWidget {
  final MapLocation location;
  final String? parcelName;
  final void Function(NavigationTarget target) onNavigate;
  final void Function(MapLocation location) onEdit;
  final void Function(MapLocation location) onDelete;

  const _LocationListTile({
    required this.location,
    this.parcelName,
    required this.onNavigate,
    required this.onEdit,
    required this.onDelete,
  });

  /// Get icon and color based on location type
  (IconData, Color) _getIconAndColor() {
    if (location.isSecnja) {
      return (Icons.carpenter, Colors.deepOrange);
    }
    return (Icons.location_on, Colors.orange);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getIconAndColor();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.2),
        child: Icon(icon, color: color),
      ),
      title: Text(location.name),
      subtitle: parcelName != null
          ? Text(
              parcelName!,
              style: TextStyle(color: Colors.green[700], fontSize: 12),
            )
          : null,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          Navigator.pop(context); // Close sheet first
          if (value == 'navigate') {
            onNavigate(
              NavigationTarget(
                location: LatLng(location.latitude, location.longitude),
                name: location.name,
              ),
            );
          } else if (value == 'edit') {
            onEdit(location);
          } else if (value == 'delete') {
            onDelete(location);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'navigate',
            child: ListTile(
              leading: Icon(Icons.navigation),
              title: Text('Navigiraj'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('Preimenuj'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Izbriši',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.pop(context);
        onNavigate(
          NavigationTarget(
            location: LatLng(location.latitude, location.longitude),
            name: location.name,
          ),
        );
      },
    );
  }
}

class _LogListTile extends StatelessWidget {
  final LogEntry log;
  final String? parcelName;
  final void Function(NavigationTarget target) onNavigate;

  const _LogListTile({
    required this.log,
    this.parcelName,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.brown.withValues(alpha: 0.2),
        child: const Icon(Icons.forest, color: Colors.brown),
      ),
      title: Text('${log.volume.toStringAsFixed(3)} m³'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (log.diameter != null && log.length != null)
            Text(
              'Ø ${log.diameter!.toStringAsFixed(0)} cm × ${log.length!.toStringAsFixed(1)} m',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          if (parcelName != null)
            Text(
              parcelName!,
              style: TextStyle(color: Colors.green[700], fontSize: 12),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.navigation),
        onPressed: () {
          Navigator.pop(context);
          onNavigate(
            NavigationTarget(
              location: LatLng(log.latitude!, log.longitude!),
              name: '${log.volume.toStringAsFixed(2)} m³',
            ),
          );
        },
      ),
      onTap: () {
        Navigator.pop(context);
        onNavigate(
          NavigationTarget(
            location: LatLng(log.latitude!, log.longitude!),
            name: '${log.volume.toStringAsFixed(2)} m³',
          ),
        );
      },
    );
  }
}

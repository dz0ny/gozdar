import 'package:flutter/material.dart';
import 'map_dialogs.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/l10n.dart';
import '../utils/parcel_labels.dart';
import '../models/map_location.dart';
import '../models/log_entry.dart';
import '../models/parcel.dart';
import '../models/navigation_target.dart';
import '../utils/formats.dart';

/// Bottom sheet displaying saved locations and logs with navigation and edit options
class SavedLocationsSheet extends StatelessWidget {
  final List<MapLocation> locations;
  final List<LogEntry> logs;
  final List<Parcel> parcels;
  final void Function(NavigationTarget target) onNavigate;
  final void Function(MapLocation location) onEdit;
  final void Function(MapLocation location) onDelete;
  final void Function()? onAddByCoordinates;

  /// Deletes a location after a swipe to the left. Returns true when it is
  /// gone. Null turns swiping off.
  final Future<bool> Function(MapLocation location)? onSwipeDelete;

  /// Opens a parcel from its group header. Null makes headers plain text.
  final void Function(Parcel parcel)? onOpenParcel;

  const SavedLocationsSheet({
    super.key,
    required this.locations,
    this.logs = const [],
    this.parcels = const [],
    required this.onNavigate,
    required this.onEdit,
    required this.onDelete,
    this.onAddByCoordinates,
    this.onSwipeDelete,
    this.onOpenParcel,
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
    Future<bool> Function(MapLocation location)? onSwipeDelete,
    void Function(Parcel parcel)? onOpenParcel,
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
          child: _SwipeableContent(
            scrollController: scrollController,
            locations: locations,
            logs: logs,
            parcels: parcels,
            onNavigate: onNavigate,
            onEdit: onEdit,
            onDelete: onDelete,
            onAddByCoordinates: onAddByCoordinates,
            onSwipeDelete: onSwipeDelete,
            onOpenParcel: onOpenParcel,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SwipeableContent(
      scrollController: ScrollController(),
      locations: locations,
      logs: logs,
      parcels: parcels,
      onNavigate: onNavigate,
      onEdit: onEdit,
      onDelete: onDelete,
      onAddByCoordinates: onAddByCoordinates,
      onSwipeDelete: onSwipeDelete,
      onOpenParcel: onOpenParcel,
    );
  }
}

/// Keeps the sheet's list in step with swipe deletes: a swiped row must leave
/// the list at once, or Dismissible fails.
class _SwipeableContent extends StatefulWidget {
  final ScrollController scrollController;
  final List<MapLocation> locations;
  final List<LogEntry> logs;
  final List<Parcel> parcels;
  final void Function(NavigationTarget target) onNavigate;
  final void Function(MapLocation location) onEdit;
  final void Function(MapLocation location) onDelete;
  final void Function()? onAddByCoordinates;
  final Future<bool> Function(MapLocation location)? onSwipeDelete;

  /// Opens a parcel from its group header. Null makes headers plain text.
  final void Function(Parcel parcel)? onOpenParcel;

  const _SwipeableContent({
    required this.scrollController,
    required this.locations,
    required this.logs,
    required this.parcels,
    required this.onNavigate,
    required this.onEdit,
    required this.onDelete,
    this.onAddByCoordinates,
    this.onSwipeDelete,
    this.onOpenParcel,
  });

  @override
  State<_SwipeableContent> createState() => _SwipeableContentState();
}

class _SwipeableContentState extends State<_SwipeableContent> {
  final _removed = <int>{};

  @override
  Widget build(BuildContext context) {
    final swipe = widget.onSwipeDelete;
    return _ContentWidget(
      scrollController: widget.scrollController,
      locations: widget.locations.where((l) => !_removed.contains(l.id)).toList(),
      logs: widget.logs,
      parcels: widget.parcels,
      onNavigate: widget.onNavigate,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
      onAddByCoordinates: widget.onAddByCoordinates,
      onSwipeDelete: swipe == null
          ? null
          : (location) async {
              final confirmed = await MapDialogs.showDeleteLocationDialog(
                context: context,
                location: location,
              );
              if (!confirmed) return false;
              return swipe(location);
            },
      onSwiped: (location) => setState(() => _removed.add(location.id)),
      onOpenParcel: widget.onOpenParcel,
    );
  }
}

/// Saved items on one parcel, or outside every parcel when [parcel] is null.
class _ParcelGroup {
  final Parcel? parcel;
  final locations = <MapLocation>[];
  final logs = <LogEntry>[];

  _ParcelGroup(this.parcel);
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

  /// Deletes a location after a swipe to the left. Returns true when it is
  /// gone. Null turns swiping off.
  final Future<bool> Function(MapLocation location)? onSwipeDelete;

  /// Opens a parcel from its group header. Null makes headers plain text.
  final void Function(Parcel parcel)? onOpenParcel;
  final void Function(MapLocation location)? onSwiped;

  const _ContentWidget({
    required this.scrollController,
    required this.locations,
    required this.logs,
    required this.parcels,
    required this.onNavigate,
    required this.onEdit,
    required this.onDelete,
    this.onAddByCoordinates,
    this.onSwipeDelete,
    this.onOpenParcel,
    this.onSwiped,
  });

  /// Wraps a location row so a swipe to the left deletes it.
  Widget _swipeable(MapLocation location, Widget child) {
    final delete = onSwipeDelete;
    if (delete == null) return child;
    return Dismissible(
      key: ValueKey('location_${location.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => delete(location),
      onDismissed: (_) => onSwiped?.call(location),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: child,
    );
  }

  /// Parcel of a sečnja mark by its link, of anything else by its position.
  /// The smallest parcel wins when parcels overlap.
  Parcel? _parcelFor(int? parcelId, double lat, double lng) {
    if (parcelId != null) {
      for (final p in parcels) {
        if (p.id == parcelId) return p;
      }
    }
    Parcel? best;
    for (final p in parcels) {
      if (!p.containsPoint(LatLng(lat, lng))) continue;
      if (best == null || p.areaM2 < best.areaM2) best = p;
    }
    return best;
  }

  /// Groups locations and logs by parcel: parcels by name, then the items
  /// outside every parcel. Inside a group: points, sečnja, then logs.
  List<_ParcelGroup> _groups(List<LogEntry> geolocatedLogs) {
    final byParcel = <Parcel?, _ParcelGroup>{};
    _ParcelGroup groupOf(Parcel? p) => byParcel.putIfAbsent(p, () => _ParcelGroup(p));
    final sorted = [
      ...locations.where((l) => !l.isSecnja),
      ...locations.where((l) => l.isSecnja),
    ];
    for (final l in sorted) {
      groupOf(_parcelFor(l.parcelId, l.latitude, l.longitude)).locations.add(l);
    }
    for (final log in geolocatedLogs) {
      groupOf(_parcelFor(log.parcelId, log.latitude!, log.longitude!)).logs.add(log);
    }
    final named = byParcel.values.where((g) => g.parcel != null).toList()
      ..sort((a, b) => a.parcel!.name.toLowerCase().compareTo(b.parcel!.name.toLowerCase()));
    return [...named, ?byParcel[null]];
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
                  context.l10n.mapwSavedLocations,
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
                    tooltip: context.l10n.mapwAddByCoordinates,
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
            child: totalCount == 0
                ? _buildEmptyState(context)
                : ListView(
              controller: scrollController,
              children: [
                for (final group in _groups(geolocatedLogs)) ...[
                  if (group.parcel case final parcel?)
                    _ParcelHeader(
                      parcel: parcel,
                      count: group.locations.length + group.logs.length,
                      onTap: onOpenParcel == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              onOpenParcel!(parcel);
                            },
                    )
                  else
                    _SectionHeader(
                      icon: Icons.not_listed_location,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      title: context.l10n.secnjaOutsideParcel,
                      count: group.locations.length + group.logs.length,
                    ),
                  for (final location in group.locations)
                    _swipeable(
                      location,
                      _LocationListTile(
                        location: location,
                        onNavigate: onNavigate,
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
                    ),
                  for (final log in group.logs)
                    _LogListTile(log: log, onNavigate: onNavigate),
                ],
              ],
            ),
          ),
        ],
      );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.mapwNoSavedLocations,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Group header of one parcel: its number or name, the k.o. and the owner,
/// as in Moj gozd. Tapping it opens the parcel.
class _ParcelHeader extends StatelessWidget {
  final Parcel parcel;
  final int count;
  final VoidCallback? onTap;

  const _ParcelHeader({required this.parcel, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sifko = parcel.cadastralMunicipality;
    final owner = parcel.owner?.trim();
    final details = [
      if (sifko != null) koLabel(sifko),
      if (owner != null && owner.isNotEmpty) owner,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          children: [
            Icon(Icons.forest, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          parcelTitle(parcel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($count)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
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
  final void Function(NavigationTarget target) onNavigate;
  final void Function(MapLocation location) onEdit;
  final void Function(MapLocation location) onDelete;

  const _LocationListTile({
    required this.location,
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
          PopupMenuItem(
            value: 'navigate',
            child: ListTile(
              leading: const Icon(Icons.navigation),
              title: Text(context.l10n.mapwMenuNavigate),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.l10n.mapwRename),
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
                context.l10n.commonDelete,
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
  final void Function(NavigationTarget target) onNavigate;

  const _LogListTile({
    required this.log,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFD4A574).withValues(alpha: 0.18),
        child: const Icon(Icons.forest, color: Color(0xFFD4A574)),
      ),
      title: Text(Fmt.m3(log.volume)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (log.diameter != null && log.length != null)
            Text(
              'Ø ${Fmt.num(log.diameter!, 0)} cm × ${Fmt.num(log.length!, 1)} m',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
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
              name: Fmt.m3(log.volume),
            ),
          );
        },
      ),
      onTap: () {
        Navigator.pop(context);
        onNavigate(
          NavigationTarget(
            location: LatLng(log.latitude!, log.longitude!),
            name: Fmt.m3(log.volume),
          ),
        );
      },
    );
  }
}

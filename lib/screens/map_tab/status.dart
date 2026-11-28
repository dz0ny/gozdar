part of '../map_tab.dart';

/// Status pills, cards and the locations sheet.
extension _Status on MapTabState {
  /// Progress/status cards shown over the top of the map, newest work first.
  Widget _buildStatusColumn(BuildContext context, MapNotifier mapProvider) {
    return ValueListenableBuilder<TileDownloadVisualState>(
      valueListenable: _tileCacheService.downloadVisualStateListenable,
      builder: (context, downloadState, _) {
        final navigationTarget = mapProvider.navigationTarget;
        final cards = <Widget>[
          if (navigationTarget != null)
            NavigationChip(
              target: navigationTarget,
              fix: _locationTracker.fix,
              onOpenCompass: showCompassForTarget,
              onEnd: clearNavigationTarget,
            ),
          if (_downloadingRegionName != null) _buildRegionDownloadCard(context),
          if (downloadState.isDownloading)
            _buildTileDownloadCard(context, downloadState),
          if (mapProvider.isQueryingParcel || _addressQuery != null)
            _buildParcelQueryPill(context),
          if (mapProvider.isLoadingLocations)
            _buildLocationsLoadingPill(context),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              cards[i],
            ],
          ],
        );
      },
    );
  }

  Widget _buildTileDownloadCard(
    BuildContext context,
    TileDownloadVisualState downloadState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  L10n.current.mapTabTilesDownloadPercent(
                    Fmt.num(downloadState.percent * 100, 1),
                  ),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: _tileCacheService.cancelDownload,
                child: Text(L10n.current.commonCancel),
              ),
            ],
          ),
          LinearProgressIndicator(
            value: downloadState.total == 0 ? null : downloadState.percent,
          ),
          const SizedBox(height: 6),
          Text(
            L10n.current.mapTabTilesDownloadStats(
              downloadState.downloaded,
              downloadState.skipped,
              downloadState.failed,
              downloadState.total,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildParcelQueryPill(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              L10n.current.mapTabSearchingParcel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsLoadingPill(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildRegionDownloadCard(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: DownloadProgressView(
          title: L10n.current.aboutDownloadingRegion,
          name: _downloadingRegionName,
          received: _regionReceived,
          total: _regionTotal,
          onCancel: () => _setState(() => _cancelRegionDownload = true),
        ),
      ),
    );
  }

  /// Show bottom sheet with saved locations
  void _showLocationsSheet() {
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    SavedLocationsSheet.show(
      context: context,
      locations: mapProvider.locations,
      logs: mapProvider.geolocatedLogs,
      parcels: mapProvider.parcels,
      onNavigate: (target) {
        setNavigationTarget(target, zoomIn: true);
      },
      onEdit: (location) {
        _editLocation(location);
      },
      onDelete: _dialogManager.showDeleteLocationDialog,
      // The sheet asks to confirm; this only deletes.
      onSwipeDelete: (location) => mapProvider.deleteLocation(location.id),
      onOpenParcel: _navigateToParcelDetail,
      onAddByCoordinates: _showAddLocationByCoordinatesDialog,
    );
  }

  /// Show dialog to add location by entering coordinates manually
  Future<void> _showAddLocationByCoordinatesDialog() async {
    final result = await MapDialogs.showAddLocationByCoordinatesDialog(
      context: context,
    );

    if (result != null) {
      await _addLocation(result.name, result.latitude, result.longitude);
      // Center map on newly added location
      if (!mounted) return;
      _camera.moveTo(
        LatLng(result.latitude, result.longitude),
        15,
        reduced: Motion.reduced(context),
      );
    }
  }
}

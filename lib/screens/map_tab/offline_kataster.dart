part of '../map_tab.dart';

/// Offline kataster overlay and region downloads.
extension _OfflineKataster on MapTabState {
  /// Invalidate the remembered padded query rect so the next
  /// [_refreshOfflineParcels] re-queries. Call when something other than panning
  /// changes what should be drawn (layer toggle, region load, recolour).
  void _invalidateOfflineQueryCache() => _offlineQueriedBounds = null;

  /// Recompute the offline kataster polygons for the current viewport. Cheap
  /// (synchronous indexed SQLite query), called on move/zoom settle. Queries a
  /// padded bounds and remembers it so subsequent pans that stay inside skip the
  /// query entirely. Clears the overlay when no offline DB is loaded or the map
  /// is zoomed out, and rebuilds the cached polygon lists used by [build].
  void _refreshOfflineParcels() {
    final generation = ++_offlineLoadGeneration;
    final svc = ParcelLookupService.instance;
    final bounds = _visibleBounds;
    final overlays = ref.read(mapNotifierProvider.notifier).activeOverlays;
    final katasterOn =
        overlays.contains(MapLayerType.kataster) ||
        overlays.contains(MapLayerType.katasterNazivi);
    if (!svc.isAvailable ||
        !katasterOn ||
        bounds == null ||
        _currentZoom < _offlineKatasterMinZoom) {
      _offlineQueriedBounds = null;
      if (_offlineParcels.isNotEmpty) {
        _setState(() {
          _offlineParcels = const [];
          _offlineExtraParts = const [];
          _publicParcelCategory = const {};
          _offlineFillPolygons = const [];
          _offlineOutlinePolygons = const [];
        });
      }
      return;
    }

    final labels = _offlineLabelsVisible;
    final anyCategory = PublicParcelSettings.instance.anyOn;

    // Skip the query+rebuild when the viewport is still inside the padded rect
    // we last queried and the label/category state hasn't changed — panning
    // within the margin needs no new data (flutter_map culls off-screen parcels).
    final cached = _offlineQueriedBounds;
    if (cached != null &&
        labels == _offlineQueriedLabels &&
        anyCategory == _offlineQueriedAnyCategory &&
        cached.containsBounds(bounds)) {
      return;
    }

    // Query a padded bounds (~40% margin) so small pans reuse the result.
    final latPad = (bounds.north - bounds.south) * 0.4;
    final lonPad = (bounds.east - bounds.west) * 0.4;
    final padded = LatLngBounds(
      LatLng(bounds.south - latPad, bounds.west - lonPad),
      LatLng(bounds.north + latPad, bounds.east + lonPad),
    );
    unawaited(
      _loadOfflineParcels(padded, bounds, labels, anyCategory, generation),
    );
  }

  /// Loads the parcels of [padded] off the UI isolate (see
  /// [MapParcelsWorker]), with each parcel's public-owner category when
  /// [anyCategory] so the polygon builder can tint by owner type.
  Future<void> _loadOfflineParcels(
    LatLngBounds padded,
    LatLngBounds visible,
    bool labels,
    bool anyCategory,
    int generation,
  ) async {
    MapParcels result;
    try {
      result = await MapParcelsWorker.instance.parcelsInBounds(
        padded,
        visible: visible,
        categories: anyCategory,
      );
    } catch (e) {
      debugPrint('Offline kataster worker failed, loading inline: $e');
      result = MapParcels(
        ParcelLookupService.instance.parcelsInBounds(
          west: padded.west,
          east: padded.east,
          south: padded.south,
          north: padded.north,
        ),
        const {},
      );
    }
    if (!mounted || generation != _offlineLoadGeneration) return;

    // A dense area holds more parcels than the limit: the worker returns the
    // screen's first, so the padding is not covered and the next pan must
    // ask again instead of reusing this result.
    _offlineQueriedBounds = result.truncated ? null : padded;
    _offlineQueriedLabels = labels;
    _offlineQueriedAnyCategory = anyCategory;
    _setState(() {
      _offlineParcels = result.parcels;
      _offlineExtraParts = result.extraParts;
      _publicParcelCategory = result.categories;
      _rebuildOfflinePolygons(labels: labels);
    });
  }

  /// Rebuild the cached fill/outline polygon lists from [_offlineParcels] and
  /// the current category/label state. Call inside a [setState] (or wrap the
  /// call). Used by [_refreshOfflineParcels] and by the recolour/label paths
  /// that change appearance without re-querying.
  void _rebuildOfflinePolygons({required bool labels}) {
    _offlineFillPolygons = [
      for (final p in _offlineParcels)
        if (_highlightCategory(p) case final cat?)
          Polygon(
            points: p.polygon,
            color: cat.fillColor,
            borderStrokeWidth: 0,
          ),
      for (final e in _offlineExtraParts)
        if (_highlightCategory(e.parcel) case final cat?)
          Polygon(points: e.ring, color: cat.fillColor, borderStrokeWidth: 0),
    ];
    final outlines = _offlineParcels.map((p) {
      // Colour the outline by public-owner category when on; otherwise the
      // default red kataster outline.
      final color = _highlightCategory(p)?.color;
      // No fill colour at all, not a transparent one: flutter_map then skips
      // the fill path of every parcel on every frame and batches all the
      // borders into one drawPath.
      return Polygon(
        points: p.polygon,
        borderColor: color ?? const Color(0xFFD50000),
        borderStrokeWidth: 2.5,
        label: labels ? p.parcelNumber : null,
        labelStyle: TextStyle(
          color: color ?? const Color(0xFFB71C1C),
          fontWeight: FontWeight.w700,
          fontSize: 12,
          // White hard-edge outline so red numbers stay readable over aerial
          // imagery.
          shadows: const [
            Shadow(color: Colors.white, offset: Offset(1, 1)),
            Shadow(color: Colors.white, offset: Offset(-1, 1)),
            Shadow(color: Colors.white, offset: Offset(1, -1)),
            Shadow(color: Colors.white, offset: Offset(-1, -1)),
          ],
        ),
      );
    }).toList();
    for (final e in _offlineExtraParts) {
      outlines.add(
        Polygon(
          points: e.ring,
          borderColor:
              _highlightCategory(e.parcel)?.color ?? const Color(0xFFD50000),
          borderStrokeWidth: 2.5,
        ),
      );
    }
    _offlineOutlinePolygons = outlines;
  }

  /// Recolour the cached polygons after a category-highlight toggle without
  /// re-querying the DB (the parcels are unchanged, only their tints). Also
  /// invalidates the query cache so the next pan re-evaluates category state.
  void _recolourOfflinePolygons() {
    _invalidateOfflineQueryCache();
    if (_offlineParcels.isEmpty) return;
    _setState(() => _rebuildOfflinePolygons(labels: _offlineLabelsVisible));
  }

  /// The camera came to rest: save it and re-cull what depends on the
  /// viewport.
  void _onCameraSettled(MapCamera camera) {
    _saveMapState();
    _visibleBounds = camera.visibleBounds;
    // Re-cull the Vlake overlay once movement settles.
    _refreshVlake();
    // Re-cull the offline kataster overlay once settled.
    _refreshOfflineParcels();
    // Offer to download the region's parcels when panning into it.
    _maybePromptRegionDownload(camera.center);
    // A region downloaded since adds auction outlines.
    AuctionService.instance.refreshOutlines();
    // Flings and the app's own moves end here, not in MapEventMoveEnd.
    unawaited(_refreshSecnjaHeader());
  }

  /// Handle a mid-gesture zoom change. The overlay/label visibility flips at the
  /// kataster min-zoom (15) and the label min-zoom (17); crossing either of those
  /// in either direction triggers an immediate refresh so the overlay/labels
  /// appear/disappear promptly. Otherwise the refresh is debounced so a
  /// continuous pinch runs at most a few queries instead of one per frame.
  void _onZoomChanged(double from, double to) {
    bool crosses(double t) => (from < t) != (to < t);
    if (crosses(_offlineKatasterMinZoom) ||
        crosses(_offlineKatasterLabelMinZoom) ||
        crosses(_vlakeMinZoom)) {
      _offlineZoomDebounce?.cancel();
      _refreshOfflineParcels();
      _refreshVlake();
      return;
    }
    _offlineZoomDebounce?.cancel();
    _offlineZoomDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _refreshOfflineParcels();
      _refreshVlake();
    });
  }

  /// When the map center lands in a statistical region whose parcels aren't
  /// loaded yet, offer to download it. Only while the kataster layer is on, and
  /// at most once per region per session.
  Future<void> _maybePromptRegionDownload(LatLng center) async {
    if (_downloadingRegionName != null) return;
    final overlays = ref.read(mapNotifierProvider.notifier).activeOverlays;
    final katasterOn =
        overlays.contains(MapLayerType.kataster) ||
        overlays.contains(MapLayerType.katasterNazivi);
    if (!katasterOn) return;

    await RegionLocator.instance.ensureLoaded();
    if (!mounted) return;
    final region = RegionLocator.instance.regionForPoint(center);
    if (region == null) return;
    if (_promptedRegions.contains(region.name)) return;
    if (ParcelLookupService.instance.loadedRegions.contains(region.name)) {
      return;
    }

    _promptedRegions.add(region.name);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(L10n.current.mapTabNoCadastreData(region.name)),
        action: SnackBarAction(
          label: L10n.current.commonDownload,
          onPressed: () => _downloadRegionByName(region.name),
        ),
      ),
    );
  }

  /// Download a region's parcels DB by name (from the auto-prompt).
  Future<void> _downloadRegionByName(String name) async {
    if (_downloadingRegionName != null) return;
    final messenger = ScaffoldMessenger.of(context);
    List<ParcelRegion> regions;
    try {
      regions = await ParcelLookupService.fetchRegions(
        ParcelLookupService.regionsManifestUrl,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is FormatException
                ? e.message
                : L10n.current.mapTabErrorWithMessage(e),
          ),
        ),
      );
      return;
    }
    ParcelRegion? match;
    for (final r in regions) {
      if (r.name == name) {
        match = r;
        break;
      }
    }
    if (match == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(L10n.current.mapTabRegionNotInList(name))),
      );
      return;
    }
    final region = match;
    _setState(() {
      _downloadingRegionName = name;
      _regionReceived = 0;
      _regionTotal = region.bytes;
      _cancelRegionDownload = false;
    });
    try {
      final result = await ParcelLookupService.instance.downloadAndOpen(
        '${ParcelLookupService.r2BaseUrl}/${region.file}',
        fileName: region.file,
        onProgress: (received, total) {
          if (!mounted) return;
          if (received - _regionReceived >= 4 * 1024 * 1024 ||
              (total != null && received >= total)) {
            _setState(() {
              _regionReceived = received;
              _regionTotal = total ?? region.bytes;
            });
          }
        },
        isCancelled: () => _cancelRegionDownload,
      );
      OwnerLookupService.instance.initPublicHr().ignore();
      if (mounted) {
        _setState(() {});
        // A new region's parcels just loaded — drop the remembered query rect so
        // the viewport (which may sit inside it) is re-queried against the new DB.
        _invalidateOfflineQueryCache();
        _refreshOfflineParcels();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              L10n.current.mapTabRegionDownloaded(name, result.rows),
            ),
          ),
        );
      }
    } on ParcelDownloadCancelled {
      messenger.showSnackBar(
        SnackBar(content: Text(L10n.current.mapTabDownloadCancelled)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is FormatException
                ? e.message
                : L10n.current.mapTabDownloadFailed(e),
          ),
        ),
      );
    } finally {
      if (mounted) {
        _setState(() {
          _downloadingRegionName = null;
          _cancelRegionDownload = false;
        });
      }
    }
  }
}

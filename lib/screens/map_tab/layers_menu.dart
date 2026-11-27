part of '../map_tab.dart';

/// Layers and the long-press menu.
extension _LayersMenu on MapTabState {
  /// Switch base layer while preserving current position
  void _switchBaseLayer(MapLayer newLayer) {
    final currentCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;

    // Clamp zoom to new layer's max zoom
    final newZoom = currentZoom.clamp(7.0, MapLayer.appMaxZoom);

    // Update provider
    ref.read(mapNotifierProvider.notifier).setBaseLayer(newLayer);

    // Move to same position with adjusted zoom if needed, preserving rotation
    if (newZoom != currentZoom) {
      final currentRotation = _mapController.camera.rotation;
      Future.microtask(() {
        if (mounted) {
          _mapController.moveAndRotate(currentCenter, newZoom, currentRotation);
        }
      });
    }
  }

  /// Show layer selection bottom sheet
  Future<void> _showLayerSelector() async {
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    final vlakeSettings = ref.read(vlakeSettingsProvider);
    await MapLayerSelector.show(
      context: context,
      currentBaseLayer: mapProvider.currentBaseLayer,
      activeOverlays: mapProvider.activeOverlays,
      workerUrl: mapProvider.workerUrl,
      onBaseLayerChanged: (layer) {
        _switchBaseLayer(layer);
      },
      onOverlayToggled: (type) {
        mapProvider.toggleOverlay(type);
        // Toggling the kataster layer doesn't fire a map event — sync the
        // offline overlay so it appears/disappears immediately.
        if (type == MapLayerType.kataster ||
            type == MapLayerType.katasterNazivi) {
          _invalidateOfflineQueryCache();
          _refreshOfflineParcels();
        }
      },
      onImportFile: _importGeoFile,
      onDownloadTiles: showTileDownloadDialog,
      vlakeAvailable: vlakeSettings.enabled,
      vlakeVisible: vlakeSettings.visible,
      onVlakeToggled: (visible) {
        ref.read(vlakeSettingsProvider.notifier).setVisible(visible);
        // Populate/clear the cached polylines immediately (data may already be
        // loaded); otherwise nothing rebuilds them until the next pan.
        _refreshVlake();
      },
      auctionsVisible: AuctionService.instance.visible,
      onAuctionsToggled: (visible) async {
        await AuctionService.instance.setVisible(visible);
        // The tint follows through _onAuctionsChanged once the list loads.
        if (visible) unawaited(AuctionService.instance.ensureLoaded());
      },
      publicParcelsAvailable: ParcelLookupService.instance.isAvailable,
      onPublicParcelsChanged: () {
        // A category toggle changes which parcels are tinted. When the
        // on/off-any state flipped, _refreshOfflineParcels re-queries to
        // (re)build _publicParcelCategory; otherwise it short-circuits and the
        // recolour below rebuilds the cached tints from existing category data.
        _refreshOfflineParcels();
        _recolourOfflinePolygons();
      },
    );
  }

  /// Format a parcel area (m²) concisely — hectares once it's large enough.
  String _formatArea(double m2) => Fmt.area(m2);

  /// Show the long-press action menu as a modal bottom sheet for the given map
  /// location.
  Future<void> _showLongPressMenu(LatLng position) async {
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    Parcel? parcelAtPosition;
    try {
      parcelAtPosition = mapProvider.parcels.firstWhere(
        (parcel) => parcel.containsPoint(position),
      );
    } catch (_) {
      parcelAtPosition = null;
    }

    // The offline kataster parcel under the press, for the per-parcel mejniki
    // toggle (boundary points come from its polygon).
    final offlineParcelAtPosition = ParcelLookupService.instance.parcelAt(
      position,
    );
    final mejnikiKey = offlineParcelAtPosition == null
        ? null
        : _parcelKey(
            offlineParcelAtPosition.cadastralMunicipality,
            offlineParcelAtPosition.parcelNumber,
          );

    // Highlight the long-pressed parcel pink while the sheet is open.
    _setState(() => _selectedParcel = offlineParcelAtPosition);

    // Concise info about the parcel under the press (from the offline DBs), shown
    // as a compact header in the sheet.
    String? parcelTitle;
    String? parcelSubtitle;
    String? parcelKo;
    OwnerInfo? parcelOwnerInfo;
    String? parcelOwner;
    String? parcelAddress;
    Future<OwnerInfo?>? parcelOwnerLookup;
    Future<ParcelValuation?>? parcelValuationLookup;
    (int, String)? parcelRef;
    PublicOwnerCategory? parcelPublicCategory;
    if (offlineParcelAtPosition != null) {
      final p = offlineParcelAtPosition;
      final ownerSvc = OwnerLookupService.instance;
      await KoLocator.instance.ensureLoaded();
      if (!mounted) return;
      final koName =
          ownerSvc.koName(p.cadastralMunicipality) ??
          KoLocator.instance.bySifko(p.cadastralMunicipality)?.name;
      final ownerInfo = ownerSvc.lookup(
        p.cadastralMunicipality,
        p.parcelNumber,
      );
      parcelOwner = ownerInfo == null ? null : ownerSummary(ownerInfo.owners);
      parcelAddress = ownerInfo?.address;
      // Croatian holders come from the DGU cadastre (cached on disk).
      if (ownerInfo == null &&
          HrOwnerService.isCroatianKo(p.cadastralMunicipality)) {
        parcelOwnerLookup = HrOwnerService.instance.lookup(
          p.cadastralMunicipality,
          p.parcelNumber,
          parcelId: p.id,
        );
      }
      // Slovenian value from the GURS register (cached on disk).
      if (SiValuationService.covers(p.cadastralMunicipality)) {
        parcelValuationLookup = SiValuationService.instance.lookup(
          p.cadastralMunicipality,
          p.parcelNumber,
        );
        parcelRef = (p.cadastralMunicipality, p.parcelNumber);
      }
      parcelPublicCategory = ownerSvc.publicCategory(
        p.cadastralMunicipality,
        p.parcelNumber,
      );
      parcelTitle = L10n.current.mapTabParcelShort(p.parcelNumber);
      parcelKo = _koLine(p.cadastralMunicipality, koName);
      parcelOwnerInfo = ownerInfo;
      parcelSubtitle = p.area > 0 ? _formatArea(p.area) : null;
    }

    final secnjaCount = parcelAtPosition == null || parcelAtPosition.id == 0
        ? 0
        : (await DatabaseService().getSecnjaByParcel(parcelAtPosition.id))
              .length;
    if (!mounted) return;

    await MapLongPressMenu.show(
      context,
      mapPosition: position,
      existingParcel: parcelAtPosition,
      parcelSecnjaCount: secnjaCount,
      onAddLocation: () => _showAddLocationDialog(position),
      onAddLog: () => _showAddLogDialog(position),
      onAddSecnja: () => _startSecnjaMarking(position),
      onImportParcel: () => _importParcelAt(position),
      onViewParcel: parcelAtPosition != null
          ? () => _navigateToParcelDetail(parcelAtPosition!)
          : null,
      parcelTitle: parcelTitle,
      parcelSubtitle: parcelSubtitle,
      parcelKo: parcelKo,
      parcelOwnerInfo: parcelOwnerInfo,
      parcelOwner: parcelOwner,
      parcelAddress: parcelAddress,
      parcelOwnerLookup: parcelOwnerLookup,
      parcelValuationLookup: parcelValuationLookup,
      parcelRef: parcelRef,
      parcelPublicCategory: parcelPublicCategory,
      onMeasureDistance: () =>
          _startMeasurement(_MeasurementTool.distance, backTo: position),
      onMeasureArea: () =>
          _startMeasurement(_MeasurementTool.area, backTo: position),
      onNavigate: () {
        // Navigate straight to the pressed point; name it after the parcel
        // under the press when there is one.
        final name =
            parcelAtPosition?.name ??
            (offlineParcelAtPosition != null
                ? L10n.current.mapTabParcelShort(
                    offlineParcelAtPosition.parcelNumber,
                  )
                : L10n.current.mapTabSelectedPoint);
        NavigateToSheet.show(
          context,
          destination: position,
          name: name,
          onInAppNavigation: () {
            setNavigationTarget(
              NavigationTarget(location: position, name: name),
              zoomIn: false,
            );
            showCompassForTarget();
          },
          onBack: () => _showLongPressMenu(position),
        );
      },
      // Show Mejniki whenever the offline kataster is loaded (a permanent
      // toolbar item like Info); it acts on the parcel under the press.
      mejnikiAvailable: ParcelLookupService.instance.isAvailable,
      showMejniki: mejnikiKey != null && _mejnikiKeys.contains(mejnikiKey),
      onToggleMejniki: (v) {
        if (mejnikiKey == null) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(content: Text(L10n.current.mapTabMejnikiHint)),
            );
          return;
        }
        _setState(() {
          if (v) {
            _mejnikiKeys.add(mejnikiKey);
          } else {
            _mejnikiKeys.remove(mejnikiKey);
          }
        });
      },
    );

    // Sheet dismissed — drop the pink highlight, but only if a newer long-press
    // hasn't already replaced the selection. (Opening a new sheet closes this
    // one, which completes the await above *after* the new sheet set its own
    // selection; without this guard we'd wipe the new highlight.)
    if (mounted && identical(_selectedParcel, offlineParcelAtPosition)) {
      _setState(() => _selectedParcel = null);
    }
  }
}

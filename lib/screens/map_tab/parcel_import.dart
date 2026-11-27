part of '../map_tab.dart';

/// Importing and printing cadastral parcels.
extension _ParcelImport on MapTabState {
  /// Query cadastral parcel at the given location and show import dialog
  /// Imports the cadastral parcel at [location] straight from the quick
  /// menu, without the confirm panel. A parcel already saved opens instead.
  Future<void> _importParcelAt(LatLng location) async {
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    if (mapProvider.isQueryingParcel) return;
    try {
      final parcel = await mapProvider.queryParcelAtLocation(location);
      if (!mounted) return;
      if (parcel == null) {
        if (_showOfflineOwnerFallback(location)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabNoParcelAtLocation)),
        );
        return;
      }
      final existing = await DatabaseService().findParcelByKoAndNumber(
        parcel.cadastralMunicipality,
        parcel.parcelNumber,
      );
      if (!mounted) return;
      if (existing != null) {
        await _navigateToParcelDetail(existing);
        return;
      }
      await _importCadastralParcel(parcel);
    } catch (e) {
      if (!mounted) return;
      if (_showOfflineOwnerFallback(location)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.current.mapTabParcelSearchError(e))),
      );
    }
  }

  /// Offline fallback: when the online cadastral lookup yields nothing, resolve
  /// the owner from the local parcel bounding boxes (if the toggle is on and the
  /// imported database carries bbox geometry). Shows the top candidate in a
  /// sheet clearly marked as approximate. Returns true when a candidate was
  /// shown, false when the fallback is unavailable or found nothing.
  bool _showOfflineOwnerFallback(LatLng location) {
    if (!OwnerOfflineSettingsService.instance.enabled) return false;
    final service = OwnerLookupService.instance;
    if (!service.isAvailable || !service.hasGeometry) return false;

    final hits = service.findOwnersAt(location.latitude, location.longitude);
    if (hits.isEmpty) return false;

    // Show the first (smallest bounding box) candidate.
    final hit = hits.first;
    final owner = hit.owner.isNotEmpty
        ? hit.owner
        : L10n.current.mapTabUnknownOwner;
    final details = [
      L10n.current.mapTabParcelKo(hit.parcela, hit.koLabel),
      if (hit.address != null) hit.address!,
    ].join('\n');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Material(
            // ListTiles paint their background and ink on the nearest
            // Material; this one sits above the sheet's colour.
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_searching,
                        color: colorScheme.tertiary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L10n.current.mapTabOwnerOffline,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(
                                  color: colorScheme.tertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            L10n.current.mapTabApproximateOffline,
                            style: Theme.of(sheetContext).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Icon(Icons.person, color: colorScheme.tertiary),
                    title: Text(
                      owner,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        details,
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close),
                  label: Text(L10n.current.commonClose),
                ),
              ],
            ),
          ),
        );
      },
    );
    return true;
  }

  /// Dismiss the import panel without importing, clearing the preview.
  void _dismissImportPanel() {
    _setState(() {
      _pendingImportParcel = null;
      _previewParcel = null;
    });
  }

  /// "BABNA POLICA (1650)", as in the Gozd list (or "KO 1650" when the name
  /// is unknown), shown on a line of its own under the parcel number.
  String _koLine(int ko, String? koName) => koName != null && koName.isNotEmpty
      ? '$koName ($ko)'
      : L10n.current.parcelFoundKo('$ko');

  /// KO line for a parcel about to be imported.
  String _importKo(CadastralParcel parcel) {
    final ko = parcel.cadastralMunicipality;
    return _koLine(
      ko,
      OwnerLookupService.instance.koName(ko) ??
          KoLocator.instance.bySifko(ko)?.name,
    );
  }

  /// Back from the import panel: close it and, when it came from the
  /// long-press menu, open that menu again for the same point.
  void _backFromImportPanel() {
    final backTo = _importBackTo;
    _importBackTo = null;
    _dismissImportPanel();
    if (backTo != null) _showLongPressMenu(backTo);
  }

  /// Confirm the import from the panel, then close it and clear the preview.
  Future<void> _confirmImportPanel() async {
    final parcel = _pendingImportParcel;
    if (parcel == null) return;
    _setState(() {
      _pendingImportParcel = null;
      _previewParcel = null;
    });
    await _importCadastralParcel(parcel);
  }

  /// Generate the parcel PDF from the panel, keeping the panel open with an
  /// inline spinner while it runs.
  Future<void> _printPendingParcel() async {
    final parcel = _pendingImportParcel;
    if (parcel == null) return;
    _setState(() => _printingParcel = true);
    try {
      await _printParcel(parcel);
    } finally {
      if (mounted) _setState(() => _printingParcel = false);
    }
  }

  /// Non-modal import panel anchored to the bottom of the map. Because it lives
  /// in the map Stack (not a route/modal), the map behind it stays fully
  /// pannable while the panel is open.
  Widget _buildImportParcelPanel(BuildContext context) {
    final parcel = _pendingImportParcel!;
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Dismissible(
            key: const ValueKey('import-parcel-panel'),
            direction: DismissDirection.down,
            confirmDismiss: (_) async => !_printingParcel,
            onDismissed: (_) => _dismissImportPanel(),
            child: Material(
              elevation: 8,
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Swipe the panel down to dismiss.
                      const SheetHandle(),
                      SheetHeader(
                        icon: Icons.download,
                        color: Colors.blue,
                        title: L10n.current.mapTabImportParcelTitle,
                        onBack: _printingParcel ? () {} : _backFromImportPanel,
                      ),
                      const SizedBox(height: 8),
                      MapDialogs.importParcelDetails(
                        context,
                        parcel,
                        title: L10n.current.mapTabParcelShort(
                          parcel.parcelNumber,
                        ),
                        koLine: _importKo(parcel),
                      ),
                      const SizedBox(height: 8),
                      SheetTileRow([
                        SheetTile(
                          icon: _printingParcel
                              ? Icons.hourglass_top
                              : Icons.print,
                          label: L10n.current.mapTabPrint,
                          color: cs.onSurfaceVariant,
                          onTap: _printingParcel ? null : _printPendingParcel,
                        ),
                        SheetTile(
                          icon: Icons.download,
                          label: L10n.current.mapTabImport,
                          color: Colors.blue,
                          onTap: _printingParcel ? null : _confirmImportPanel,
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Generate a PDF of the parcel (map snapshot + attributes, using the layers
  /// currently shown on the map), save it to a temp file and open it in the
  /// device's PDF viewer.
  Future<void> _printParcel(CadastralParcel cadastralParcel) async {
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ParcelPdfService.instance.buildParcelPdf(
        parcel: cadastralParcel,
        baseLayer: mapProvider.currentBaseLayer,
        activeOverlays: mapProvider.activeOverlays,
        workerUrl:
            mapProvider.workerUrl ?? MapPreferencesService.defaultWorkerUrl,
      );
      final safeNumber = cadastralParcel.parcelNumber.replaceAll(
        RegExp(r'[^0-9A-Za-z]+'),
        '-',
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/parcela-$safeNumber.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(L10n.current.mapTabPdfOpenFailed(result.message)),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(L10n.current.mapTabPdfError(e))),
      );
    }
  }

  /// Import a cadastral parcel into the database
  Future<void> _importCadastralParcel(CadastralParcel cadastralParcel) async {
    try {
      final mapProvider = ref.read(mapNotifierProvider.notifier);
      final success = await mapProvider.importCadastralParcel(cadastralParcel);

      if (mounted) {
        if (success) {
          // Download tiles for offline use in the background
          _downloadTilesForParcel(cadastralParcel.polygon);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.current.mapTabParcelImported(
                  cadastralParcel.cadastralMunicipality,
                  cadastralParcel.parcelNumber,
                ),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.current.mapTabErrorWithMessage(mapProvider.error ?? ''),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabParcelImportError(e))),
        );
      }
    }
  }

  /// Import geodata from file (KML or KMZ)
  Future<void> _importGeoFile() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['kml', 'kmz'],
      );

      if (picked == null) return;

      // TODO: Handle KML/KMZ import
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabKmlUnsupported)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabImportError(e))),
        );
      }
    }
  }

  /// Download tiles for a parcel's bounding box in the background
  void _downloadTilesForParcel(List<LatLng> polygon) {
    if (polygon.isEmpty) return;

    // Calculate bounding box from polygon with some padding
    double minLat = polygon.first.latitude;
    double maxLat = polygon.first.latitude;
    double minLng = polygon.first.longitude;
    double maxLng = polygon.first.longitude;

    for (final point in polygon) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add ~100m padding around the parcel
    const padding = 0.001; // ~100m in degrees
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    // Start background download (fire-and-forget)
    _tileCacheService.downloadForParcelBounds(bounds);
  }
}

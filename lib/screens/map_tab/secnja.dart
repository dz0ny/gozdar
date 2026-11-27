part of '../map_tab.dart';

/// Sečnja marking.
extension _Secnja on MapTabState {
  /// Enters the sečnja marking mode with the crosshair on [position].
  Future<void> _startSecnjaMarking(LatLng position) async {
    _mapController.move(position, _mapController.camera.zoom);
    final species = await SpeciesService().getSpecies();
    final remembered = await _secnjaPrefs.getSpecies();
    if (!mounted) return;
    _setState(() {
      _secnjaMarking = true;
      _secnjaSession.clear();
      _secnjaSpeciesList = species;
      _secnjaSpecies = species.contains(remembered) ? remembered : null;
    });
    await _refreshSecnjaHeader();
  }

  /// Updates the panel header for the parcel under the crosshair.
  Future<void> _refreshSecnjaHeader() async {
    if (!_secnjaMarking) return;
    final db = DatabaseService();
    final center = _mapController.camera.center;
    final parcelId = await db.parcelIdAt(center);
    final count = parcelId == null
        ? await db.countSecnjaWithoutParcel()
        : (await db.getSecnjaByParcel(parcelId)).length;
    final parcel = parcelId == null ? null : await db.getParcel(parcelId);
    if (!mounted || !_secnjaMarking) return;
    _setState(() {
      _secnjaCount = count;
      _secnjaTitle = parcel == null
          ? L10n.current.secnjaOutsideParcel
          : L10n.current.secnjaMarkingTitle(parcel.parcelNumber ?? parcel.name);
    });
  }

  /// Marks the tree under the crosshair.
  Future<void> _markSecnjaAtCrosshair() async {
    HapticFeedback.mediumImpact();
    final MapLocation mark;
    try {
      mark = await markSecnjaAt(
        _mapController.camera.center,
        species: _secnjaSpecies,
        l10n: L10n.current,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabSecnjaMarkError(e))),
        );
      }
      return;
    }
    _secnjaSession.add(mark);
    if (!mounted) return;
    await _refreshSecnjaHeader();
    if (mark.parcelId == null) unawaited(_importSecnjaParcel(mark));
  }

  /// A mark outside every saved parcel imports the cadastral parcel under it,
  /// so the trees can be shared. Marking does not wait for it.
  Future<void> _importSecnjaParcel(MapLocation mark) async {
    if (_importingSecnjaParcel) return;
    _importingSecnjaParcel = true;
    final mapProvider = ref.read(mapNotifierProvider.notifier);
    try {
      CadastralParcel? imported;
      final parcelId = await importSecnjaParcelAt(
        LatLng(mark.latitude, mark.longitude),
        query: mapProvider.queryParcelAtLocation,
        import: (parcel) async {
          imported = parcel;
          return mapProvider.importCadastralParcel(parcel);
        },
      );
      final parcel = imported;
      if (parcelId == null || parcel == null || !mounted) return;
      _downloadTilesForParcel(parcel.polygon);
      // Končaj opens the parcel of these marks for Deli sekaču.
      for (final m in _secnjaSession) {
        m.parcelId ??= await DatabaseService().parcelIdAt(
          LatLng(m.latitude, m.longitude),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10n.current.mapTabParcelImported(
              parcel.cadastralMunicipality,
              parcel.parcelNumber,
            ),
          ),
        ),
      );
      await _refreshSecnjaHeader();
    } catch (_) {
      // The mark stays without a parcel. The owner can import it by hand.
    } finally {
      _importingSecnjaParcel = false;
    }
  }

  /// Removes the last mark of this session.
  Future<void> _undoSecnjaMark() async {
    if (_secnjaSession.isEmpty) return;
    final last = _secnjaSession.removeLast();
    await DatabaseService().deleteLocation(last.id);
    if (!mounted) return;
    await _refreshSecnjaHeader();
  }

  Future<void> _selectSecnjaSpecies(String? species) async {
    _setState(() => _secnjaSpecies = species);
    await _secnjaPrefs.setSpecies(species);
  }

  Future<void> _addSecnjaSpecies() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => const SpeciesManagementSheet(),
    );
    final species = await SpeciesService().getSpecies();
    if (!mounted) return;
    _setState(() {
      _secnjaSpeciesList = species;
      if (!species.contains(_secnjaSpecies)) _secnjaSpecies = null;
    });
  }

  /// Leaves the marking mode and offers to share the last marked parcel.
  void _finishSecnjaMarking() {
    final marked = _secnjaSession.length;
    final parcelId = _secnjaSession.reversed
        .map((m) => m.parcelId)
        .firstWhere((id) => id != null, orElse: () => null);
    _setState(() {
      _secnjaMarking = false;
      _secnjaSession.clear();
    });
    if (marked == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10n.current.secnjaMarkedSnack(marked)),
        action: parcelId == null ? null : _secnjaShareSnackAction(parcelId),
      ),
    );
  }

  /// Snackbar action that opens [parcelId] at its Sečnja card, where the
  /// owner sees the marks and shares them.
  SnackBarAction _secnjaShareSnackAction(int parcelId) => SnackBarAction(
    label: L10n.current.secnjaShareAction,
    onPressed: () async {
      final parcel = await DatabaseService().getParcel(parcelId);
      if (parcel == null || !mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) =>
              ParcelDetailScreen(parcel: parcel, showSecnja: true),
        ),
      );
    },
  );

  Widget _buildSecnjaPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SecnjaMarkingPanel(
        title: _secnjaTitle,
        count: _secnjaCount,
        species: _secnjaSpeciesList,
        selectedSpecies: _secnjaSpecies,
        onSpeciesSelected: _selectSecnjaSpecies,
        onAddSpecies: _addSecnjaSpecies,
        onUndo: _secnjaSession.isEmpty ? null : _undoSecnjaMark,
        onMark: _markSecnjaAtCrosshair,
        onLocate: _centerOnGpsLocation,
        onFinish: _finishSecnjaMarking,
      ),
    );
  }
}

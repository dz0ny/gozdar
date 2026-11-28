part of '../map_tab.dart';

/// Parcel and address search results.
extension _Search on MapTabState {
  /// A house number from the search: show the parcel under it, from the
  /// offline cadastre when a region is loaded, else from the ZGS service.
  /// Without a parcel the map only moves to the house.
  Future<void> _handleAddressFound(AddressHit hit) async {
    final lookup = ++_addressLookup;
    _camera.moveTo(hit.point, 18, reduced: Motion.reduced(context));
    var parcel = ParcelLookupService.instance.parcelAt(hit.point);
    if (parcel == null) {
      // The offline cadastre has no parcel here. The network can be slow.
      _setState(() => _addressQuery = lookup);
      try {
        parcel = await CadastralService().queryParcelAtLocation(hit.point);
      } finally {
        // A newer lookup has its own pill, or none.
        if (mounted && _addressQuery == lookup) {
          _setState(() => _addressQuery = null);
        }
      }
    } else if (_addressQuery != null) {
      // An older lookup still waits. Its answer is dropped below.
      _setState(() => _addressQuery = null);
    }
    // A newer address search owns the map now.
    if (!mounted || lookup != _addressLookup) return;
    if (parcel == null || parcel.polygon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.current.parcelSearchAddressNoParcel(hit.title)),
        ),
      );
      return;
    }
    await _handleParcelFound(
      WfsParcel(
        localId: parcel.id,
        label: parcel.parcelNumber,
        nationalCadastralReference:
            '${parcel.cadastralMunicipality} ${parcel.parcelNumber}',
        area: parcel.area,
        polygon: parcel.polygon,
        referencePoint: hit.point,
      ),
    );
  }

  /// Handle when a parcel is found from search
  Future<void> _handleParcelFound(WfsParcel parcel) async {
    _setState(() {
      _searchedParcel = parcel;
    });

    // Fit map to parcel bounds
    if (parcel.polygon.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(parcel.polygon);
      _camera.fitBounds(
        bounds,
        padding: const EdgeInsets.all(50),
        maxZoom: 17,
        reduced: Motion.reduced(context),
      );
    }

    // Check if parcel already exists in database
    final koInt = int.tryParse(parcel.koNumber);
    final existingParcel = await DatabaseService().findParcelByKoAndNumber(
      koInt,
      parcel.parcelNumber,
    );

    if (!mounted) return;

    // Non-modal sheet: no backdrop, so the map stays usable under it.
    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null) return;
    final controller = ParcelFoundSheet.show(
      scaffold: scaffold,
      wfsParcel: parcel,
      existingParcel: existingParcel,
      onHide: () {},
      onAction: () async {
        if (existingParcel != null) {
          // Parcel already exists - navigate to Forest tab
          ref
              .read(navigationNotifierProvider.notifier)
              .navigateToForestWithParcel(existingParcel);
          context.go(
            AppRoutes.parcelDetail(existingParcel.id),
            extra: existingParcel,
          );
        } else {
          // Parcel doesn't exist - import it
          await _importSearchedParcel(parcel);
        }
      },
    );
    // Clear the temporary blue overlay however the sheet goes away (after an
    // import the imported parcel draws its own outline).
    controller.closed.whenComplete(() {
      // A newer search may already have replaced this parcel and sheet.
      if (mounted && identical(_searchedParcel, parcel)) {
        _setState(() {
          _searchedParcel = null;
        });
      }
    });
  }

  /// The row for My parcels, named like the Forest tab names imports.
  Future<Parcel> _parcelFromWfs(WfsParcel wfsParcel) async {
    final koInt = int.tryParse(wfsParcel.koNumber);
    // Croatian holders are only fetched live, so keep them with the parcel.
    final hrOwner = HrOwnerService.isCroatianKo(koInt)
        ? await HrOwnerService.instance.lookup(koInt!, wfsParcel.parcelNumber)
        : null;
    return Parcel(
      name: await KoLocator.defaultParcelName(
        koInt,
        wfsParcel.parcelNumber,
        fallbackKo: wfsParcel.koNumber,
      ),
      polygon: wfsParcel.polygon,
      cadastralMunicipality: koInt,
      parcelNumber: wfsParcel.parcelNumber,
      owner: hrOwner?.displayOwners,
      createdAt: DateTime.now(),
    );
  }

  /// Quick add from the search sheet: save without moving the map or
  /// closing the sheet. False when the parcel was already saved.
  Future<bool> _quickAddParcel(WfsParcel wfsParcel) async {
    final db = DatabaseService();
    final existing = await db.findParcelByKoAndNumber(
      int.tryParse(wfsParcel.koNumber),
      wfsParcel.parcelNumber,
    );
    if (existing != null) return false;
    await db.insertParcel(await _parcelFromWfs(wfsParcel));
    return true;
  }

  /// Import the searched parcel into the database
  Future<void> _importSearchedParcel(WfsParcel wfsParcel) async {
    try {
      final dbService = DatabaseService();

      // Convert KO number from string to int
      final koInt = int.tryParse(wfsParcel.koNumber);

      // Check if parcel already exists
      final existingParcel = await dbService.findParcelByKoAndNumber(
        koInt,
        wfsParcel.parcelNumber,
      );

      if (existingParcel != null) {
        // Parcel already exists - show option to view it
        if (mounted) {
          final viewParcel = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(L10n.current.mapTabParcelExistsTitle),
              content: Text(
                L10n.current.mapTabParcelExistsLabelBody(wfsParcel.label),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(L10n.current.commonClose),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.visibility),
                  label: Text(L10n.current.mapTabShowInMyParcels),
                ),
              ],
            ),
          );

          if (viewParcel == true && mounted) {
            ref
                .read(navigationNotifierProvider.notifier)
                .navigateToForestWithParcel(existingParcel);
            context.go(
              AppRoutes.parcelDetail(existingParcel.id),
              extra: existingParcel,
            );
          }
        }
        return;
      }

      await dbService.insertParcel(await _parcelFromWfs(wfsParcel));

      // Clear searched parcel
      _setState(() {
        _searchedParcel = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.current.mapTabParcelImportedSimple)),
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
}

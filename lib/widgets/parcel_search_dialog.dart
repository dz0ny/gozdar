import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/auction_service.dart';
import '../services/cadastral_service.dart';
import '../services/ko_locator.dart';
import '../services/parcel_search_service.dart';
import 'auction_sheet.dart';
import 'parcel_info_widgets.dart';
import 'parcel_search_controller.dart';
import '../l10n/l10n.dart';

/// Bottom sheet for finding a cadastral parcel with a single search field.
///
/// The field autocompletes cadastral municipality names and codes, parcel
/// numbers (`123`, `123/4`) and owner names. The KO the map is looking at is
/// preselected as a removable chip; typing a KO name switches it. Tapping a
/// parcel or owner suggestion fetches the geometry and hands it to
/// [onParcelFound].
class ParcelSearchDialog extends StatefulWidget {
  final MapController mapController;
  final Function(WfsParcel) onParcelFound;

  /// Where the map is looking, to preselect its KO. Defaults to the
  /// controller's camera centre.
  final LatLng? center;

  const ParcelSearchDialog({
    super.key,
    required this.mapController,
    required this.onParcelFound,
    this.center,
  });

  @override
  State<ParcelSearchDialog> createState() => _ParcelSearchDialogState();

  /// Forget the remembered query (tests).
  @visibleForTesting
  static void forgetLastSearch() {
    _LastSearch.text = '';
    _LastSearch.ko = null;
  }

  static Future<void> show({
    required BuildContext context,
    required MapController mapController,
    required Function(WfsParcel) onParcelFound,
    LatLng? center,
  }) {
    if (center == null) {
      try {
        center = mapController.camera.center;
      } catch (_) {
        // Controller not attached to a map yet: no prefill.
      }
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      showDragHandle: true,
      builder: (context) => ParcelSearchDialog(
        mapController: mapController,
        onParcelFound: onParcelFound,
        center: center,
      ),
    );
  }
}

/// The last query and KO, kept for the app session so reopening the search
/// (e.g. after looking at a found parcel on the map) shows the same results.
class _LastSearch {
  static String text = '';
  static KoInfo? ko;
}

class _ParcelSearchDialogState extends State<ParcelSearchDialog> {
  final _controller = ParcelSearchController();
  final _cadastralService = CadastralService();

  /// The user picked or removed the KO, so a late map-position prefill must
  /// not overwrite it.
  bool _koTouched = false;
  bool _koFromMap = false;

  /// Court auctions instead of the parcel search.
  bool _auctions = false;

  /// Key of the suggestion whose geometry is being fetched.
  String? _locatingKey;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_LastSearch.text.trim().isNotEmpty) {
      // Restore the previous search, selected so typing replaces it.
      _koTouched = true;
      _controller.text.value = TextEditingValue(
        text: _LastSearch.text,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: _LastSearch.text.length,
        ),
      );
      _controller.setKo(_LastSearch.ko);
    } else {
      _prefillKo();
    }
    _controller.addListener(_remember);
  }

  void _remember() {
    _LastSearch.text = _controller.text.text;
    _LastSearch.ko = _controller.ko;
  }

  @override
  void dispose() {
    _controller.removeListener(_remember);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prefillKo() async {
    final center = widget.center;
    if (center == null) return;
    final ko = await ParcelSearchService.koForPoint(center);
    if (!mounted || _koTouched || ko == null) return;
    setState(() => _koFromMap = true);
    _controller.setKo(ko);
  }

  void _setKo(KoInfo? ko, {String? keepText}) {
    _koTouched = true;
    setState(() {
      _koFromMap = false;
      _error = null;
    });
    if (keepText != null) {
      _controller.text.value = TextEditingValue(
        text: keepText,
        selection: TextSelection.collapsed(offset: keepText.length),
      );
    }
    _controller.setKo(ko);
    _controller.focus.requestFocus();
  }

  String _key(ParcelSuggestion s) => '${s.sifko}/${s.parcela}';

  Future<void> _open(ParcelSuggestion s) async {
    setState(() {
      _locatingKey = _key(s);
      _error = null;
    });
    try {
      final parcel = await _cadastralService.queryParcelByKoAndNumber(
        s.sifko.toString(),
        s.parcela!,
      );
      if (!mounted) return;
      if (parcel != null && parcel.polygon.isNotEmpty) {
        Navigator.of(context).pop();
        widget.onParcelFound(parcel);
        return;
      }
      setState(() {
        _locatingKey = null;
        _error = L10n.current.parcelSearchNotFound(s.parcela!);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locatingKey = null;
        _error = L10n.current.parcelSearchError('$e');
      });
    }
  }

  void _onSuggestionTap(ParcelSuggestion s) {
    if (s.kind == ParcelSuggestionKind.ko) {
      // Keep a typed parcel number, drop the words that named the KO.
      final number = ParsedParcelQuery.parse(_controller.text.text).parcelNumber;
      _setKo(s.ko, keepText: number ?? '');
    } else {
      _open(s);
    }
  }

  /// Keyboard "search": open the first parcel/owner row, else take the KO.
  void _submit() {
    // The auctions tab filters as you type; there is nothing to submit.
    if (_locatingKey != null || _auctions) return;
    final rows = _controller.suggestions;
    if (rows.isEmpty) return;
    final target = rows.firstWhere(
      (s) => s.kind != ParcelSuggestionKind.ko,
      orElse: () => rows.first,
    );
    _onSuggestionTap(target);
  }

  @override
  Widget build(BuildContext context) {
    // Size the sheet to the space above the keyboard so typing shrinks the
    // list instead of pushing the field off screen.
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.viewInsets.bottom - media.padding.top - 56;
    final height = available.clamp(240.0, media.size.height * 0.92);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              _tabs(context),
              if (!_auctions) _koChip(context),
              _field(context),
              SizedBox(
                height: 2,
                child: (_controller.searchingOwners || _locatingKey != null)
                    ? const LinearProgressIndicator()
                    : const Divider(height: 1),
              ),
              if (_error != null) _errorBox(context, _error!),
              Expanded(
                child: _auctions ? _auctionList(context) : _body(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      child: Row(
        children: [
          Icon(Icons.search, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.parcelSearchTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonCancel,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: false,
            icon: const Icon(Icons.grid_on),
            label: Text(context.l10n.searchTabParcels),
          ),
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.gavel),
            label: Text(context.l10n.searchTabAuctions),
          ),
        ],
        selected: {_auctions},
        onSelectionChanged: (v) => setState(() {
          _auctions = v.first;
          _error = null;
        }),
      ),
    );
  }

  /// Distance in degrees² from the map centre to the middle of [a]'s KO,
  /// for "nearest first"; KOs the index doesn't know go last.
  double _distance(Auction a) {
    final ko = KoLocator.instance.bySifko(a.sifko);
    final c = widget.center;
    if (ko == null || c == null) return double.infinity;
    final dLat = (ko.minLat + ko.maxLat) / 2 - c.latitude;
    final dLon = (ko.minLon + ko.maxLon) / 2 - c.longitude;
    return dLat * dLat + dLon * dLon;
  }

  /// Current court auctions, nearest first, filtered by the field's KO name,
  /// KO code or parcel number. Tapping one opens the parcel on the map.
  Widget _auctionList(BuildContext context) {
    return FutureBuilder<void>(
      future: AuctionService.instance.ensureLoaded(),
      builder: (context, snapshot) {
        final all = AuctionService.instance.all;
        if (all.isEmpty) {
          return snapshot.connectionState == ConnectionState.done
              ? _hint(context, Icons.gavel, context.l10n.auctionsEmpty)
              : _hint(context, Icons.gavel, context.l10n.auctionsLoading);
        }
        final words = KoLocator.fold(_controller.text.text)
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();
        bool matches(Auction a) {
          final hay = KoLocator.fold('${a.sifko} ${a.koName ?? ''} ${a.parcela}');
          return words.every(hay.contains);
        }

        final list = [for (final a in all) if (matches(a)) a]
          ..sort((a, b) => _distance(a).compareTo(_distance(b)));
        if (list.isEmpty) {
          return _hint(context, Icons.search_off, context.l10n.auctionsEmpty);
        }
        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: list.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  context.l10n.auctionsHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              );
            }
            return _auctionTile(context, list[i - 1]);
          },
        );
      },
    );
  }

  Widget _auctionTile(BuildContext context, Auction a) {
    final cs = Theme.of(context).colorScheme;
    final suggestion = ParcelSuggestion(
      kind: ParcelSuggestionKind.parcel,
      title: context.l10n.mapTabParcelShort(a.parcela),
      sifko: a.sifko,
      parcela: a.parcela,
    );
    final locating = _locatingKey == _key(suggestion);
    final ko = a.koName != null ? '${a.sifko} ${a.koName}' : '${a.sifko}';
    return ListTile(
      minVerticalPadding: 10,
      leading: Icon(Icons.gavel, color: cs.primary),
      title: Text(
        '${context.l10n.mapTabParcelShort(a.parcela)} · '
        '${context.l10n.parcelFoundKo(ko)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        [
          if (a.startingPrice != null) '${euros(context, a.startingPrice!)} €',
          auctionDate(context, a.saleStartAt),
          if (a.kind != null) a.kind!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: locating
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.my_location, color: cs.onSurfaceVariant),
      onTap: _locatingKey != null ? null : () => _open(suggestion),
    );
  }

  Widget _koChip(BuildContext context) {
    final ko = _controller.ko;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ko == null
            ? Chip(
                avatar: const Icon(Icons.place_outlined, size: 18),
                label: Text(context.l10n.parcelSearchAllKo),
              )
            : InputChip(
                avatar: Icon(
                  _koFromMap ? Icons.my_location : Icons.place,
                  size: 18,
                ),
                label: Text(
                  context.l10n.parcelFoundKo(ko.label),
                  overflow: TextOverflow.ellipsis,
                ),
                tooltip: _koFromMap ? context.l10n.parcelSearchByMapPosition : null,
                deleteButtonTooltipMessage: context.l10n.parcelSearchRemoveKo,
                onDeleted: () => _setKo(null),
              ),
      ),
    );
  }

  Widget _field(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _controller.text,
        focusNode: _controller.focus,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.titleMedium,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
          _controller.queryChanged();
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: context.l10n.parcelSearchHint,
          helperText: context.l10n.parcelSearchHelper,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.hasQuery
              ? IconButton(
                  tooltip: context.l10n.parcelEditorClear,
                  icon: Icon(Icons.clear, color: cs.onSurfaceVariant),
                  onPressed: () {
                    _controller.text.clear();
                    _controller.queryChanged();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final rows = _controller.suggestions;
    final parsed = ParsedParcelQuery.parse(_controller.text.text);
    final needsKo = parsed.parcelNumber != null &&
        _controller.ko == null &&
        !rows.any((s) => s.kind == ParcelSuggestionKind.parcel);

    if (!_controller.hasQuery) {
      return _hint(
        context,
        Icons.travel_explore,
        _controller.ko == null
            ? context.l10n.parcelSearchPromptNoKo
            : context.l10n.parcelSearchPromptWithKo,
      );
    }
    if (rows.isEmpty) {
      if (_controller.searchingOwners) return const SizedBox.shrink();
      return _hint(
        context,
        needsKo ? Icons.place_outlined : Icons.search_off,
        needsKo
            ? context.l10n.parcelSearchNeedsKoHint(parsed.parcelNumber!)
            : context.l10n.parcelSearchNoResults,
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: rows.length + (needsKo ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (needsKo && i == 0) {
          return ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              context.l10n.parcelSearchNeedsKo(parsed.parcelNumber!),
            ),
          );
        }
        return _tile(context, rows[i - (needsKo ? 1 : 0)]);
      },
    );
  }

  Widget _tile(BuildContext context, ParcelSuggestion s) {
    final cs = Theme.of(context).colorScheme;
    final locating = _locatingKey == _key(s);
    final (icon, trailing) = switch (s.kind) {
      ParcelSuggestionKind.parcel => (Icons.grid_on, Icons.my_location),
      ParcelSuggestionKind.owner => (Icons.person_search, Icons.my_location),
      ParcelSuggestionKind.ko => (Icons.place_outlined, Icons.add),
    };
    return ListTile(
      minVerticalPadding: 10,
      leading: Icon(icon, color: cs.primary),
      title: Text(
        s.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: s.subtitle == null
          ? null
          : Text(s.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: locating
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(trailing, color: cs.onSurfaceVariant),
      onTap: _locatingKey != null ? null : () => _onSuggestionTap(s),
    );
  }

  Widget _hint(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: cs.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/ko_locator.dart';
import '../services/parcel_search_service.dart';

/// State of the parcel-search sheet: the query, the selected KO and the
/// suggestions. KO and parcel-number suggestions update on every keystroke;
/// owner matches are debounced and run off the UI thread, and a result from a
/// query that a newer one replaced is dropped.
class ParcelSearchController extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  ParcelSearchController({KoInfo? ko, this.ownerDebounce}) : _ko = ko;

  final text = TextEditingController();
  final focus = FocusNode();

  /// Overrides the owner-search debounce (tests).
  final Duration? ownerDebounce;

  KoInfo? _ko;
  KoInfo? get ko => _ko;

  List<ParcelSuggestion> _instant = const [];
  List<ParcelSuggestion> _owners = const [];
  bool _searchingOwners = false;
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;

  bool get searchingOwners => _searchingOwners;
  bool get hasQuery => text.text.trim().isNotEmpty;

  /// Parcel and KO rows first, then owners.
  List<ParcelSuggestion> get suggestions => [..._instant, ..._owners];

  void setKo(KoInfo? ko) {
    _ko = ko;
    queryChanged();
  }

  /// Call from the field's `onChanged`.
  void queryChanged() {
    _debounce?.cancel();
    _generation++; // drop any owner search still in flight
    final query = text.text;
    _instant = ParcelSearchService.instant(query, ko: _ko);
    _owners = const [];
    _searchingOwners = false;
    final parsed = ParsedParcelQuery.parse(query);
    if (parsed.parcelNumber == null && parsed.words.length >= 3) {
      _searchingOwners = true;
      _debounce = Timer(
        ownerDebounce ?? const Duration(milliseconds: 250),
        _runOwners,
      );
    }
    notifyListeners();
  }

  Future<void> _runOwners() async {
    final generation = ++_generation;
    List<ParcelSuggestion> found;
    try {
      found = await ParcelSearchService.owners(text.text, ko: _ko);
    } catch (e) {
      debugPrint('ParcelSearchController owner search failed: $e');
      found = const [];
    }
    if (_disposed || generation != _generation) return;
    _owners = found;
    _searchingOwners = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    text.dispose();
    focus.dispose();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/address_lookup_service.dart';
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
  List<ParcelSuggestion> _addresses = const [];
  List<ParcelSuggestion> _owners = const [];
  bool _searchingOwners = false;
  bool _searchingAddresses = false;
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;

  bool get searchingOwners => _searchingOwners;

  /// True while owner or address rows are still to come.
  bool get searching => _searchingOwners || _searchingAddresses;
  bool get hasQuery => text.text.trim().isNotEmpty;

  /// Parcel and KO rows first, then addresses, then owners.
  List<ParcelSuggestion> get suggestions => [
    ..._instant,
    ..._addresses,
    ..._owners,
  ];

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
    _addresses = const [];
    _owners = const [];
    _searchingOwners = false;
    _searchingAddresses = false;
    final parsed = ParsedParcelQuery.parse(query);
    final wantOwners = parsed.parcelNumber == null && parsed.words.length >= 3;
    final wantAddresses =
        AddressLookupService.instance.isAvailable &&
        parsed.words.length >= AddressLookupService.minQueryLength;
    if (wantOwners || wantAddresses) {
      _searchingOwners = wantOwners;
      _searchingAddresses = wantAddresses;
      _debounce = Timer(
        ownerDebounce ?? const Duration(milliseconds: 250),
        () => _runDeferred(owners: wantOwners, addresses: wantAddresses),
      );
    }
    notifyListeners();
  }

  /// The address rows are indexed lookups and run right away; the owner
  /// search runs off the UI thread.
  Future<void> _runDeferred({
    required bool owners,
    required bool addresses,
  }) async {
    final generation = ++_generation;
    final query = text.text;
    if (addresses) {
      try {
        _addresses = ParcelSearchService.addresses(query, ko: _ko);
      } catch (e) {
        debugPrint('ParcelSearchController address search failed: $e');
        _addresses = const [];
      }
      _searchingAddresses = false;
      notifyListeners();
    }
    if (!owners) return;
    List<ParcelSuggestion> found;
    try {
      found = await ParcelSearchService.owners(query, ko: _ko);
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

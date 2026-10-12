import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/owner_lookup_service.dart';

/// Owner search state shared by the search sheet and the owner import screen:
/// debounces typing, runs the search off the UI thread and drops results
/// from queries that a newer one has replaced.
class OwnerSearchController extends ChangeNotifier {
  OwnerSearchController({this.limit = 300});

  final int limit;
  final name = TextEditingController();
  final address = TextEditingController();

  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;

  bool _searching = false;
  bool get searching => _searching;

  OwnerSearchResult _result = OwnerSearchResult.empty;
  OwnerSearchResult get result => _result;

  bool get hasQuery =>
      name.text.trim().isNotEmpty || address.text.trim().isNotEmpty;

  /// Call from the fields' `onChanged`.
  void queryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _run);
    notifyListeners();
  }

  Future<void> _run() async {
    final generation = ++_generation;
    _searching = true;
    notifyListeners();

    OwnerSearchResult result;
    try {
      result = await OwnerLookupService.instance.searchOwnersAsync(
        name: name.text,
        address: address.text,
        limit: limit,
      );
    } catch (e) {
      debugPrint('OwnerSearchController search failed: $e');
      result = OwnerSearchResult.empty;
    }
    // A newer query started while this one ran; its result wins.
    if (_disposed || generation != _generation) return;
    _result = result;
    _searching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    name.dispose();
    address.dispose();
    super.dispose();
  }
}

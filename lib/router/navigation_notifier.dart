import 'package:flutter/foundation.dart';
import '../models/navigation_target.dart';
import '../models/parcel.dart';

/// Handles cross-tab navigation commands for go_router
/// Replaces MainScreen.navigateToMapWithTarget(), etc.
class NavigationNotifier extends ChangeNotifier {
  NavigationTarget? _pendingNavigationTarget;
  Parcel? _pendingParcelToShow;
  bool _shouldShowSearch = false;

  /// Pending navigation target for map tab
  NavigationTarget? get pendingNavigationTarget => _pendingNavigationTarget;

  /// Pending parcel to show in forest tab
  Parcel? get pendingParcelToShow => _pendingParcelToShow;

  /// Whether to show search dialog when switching to map
  bool get shouldShowSearch => _shouldShowSearch;

  /// Navigate to map tab with a navigation target
  void navigateToMapWithTarget(NavigationTarget target) {
    _pendingNavigationTarget = target;
    notifyListeners();
  }

  /// Navigate to forest tab and show parcel detail
  void navigateToForestWithParcel(Parcel parcel) {
    _pendingParcelToShow = parcel;
    notifyListeners();
  }

  /// Navigate to map tab and show search dialog
  void navigateToMapWithSearch() {
    _shouldShowSearch = true;
    notifyListeners();
  }

  /// Clear pending navigation target (call after handling)
  void clearNavigationTarget() {
    _pendingNavigationTarget = null;
  }

  /// Clear pending parcel (call after handling)
  void clearPendingParcel() {
    _pendingParcelToShow = null;
  }

  /// Clear search flag (call after handling)
  void clearSearchFlag() {
    _shouldShowSearch = false;
  }
}

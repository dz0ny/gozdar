import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/navigation_target.dart';
import '../models/parcel.dart';
import 'route_names.dart';

/// Shows [target] on the map. A screen pushed with Navigator covers the
/// map, so this closes it first.
void goToMapWithTarget(BuildContext context, NavigationTarget target) {
  context.read<NavigationNotifier>().navigateToMapWithTarget(target);
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context);
  if (ModalRoute.of(context)?.settings is! Page && navigator.canPop()) {
    navigator.pop();
  }
  router.go(AppRoutes.map);
}

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

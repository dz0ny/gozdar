import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';

import '../models/navigation_target.dart';
import '../models/parcel.dart';
import 'route_names.dart';

part 'navigation_notifier.freezed.dart';

/// Shows [target] on the map. A screen pushed with Navigator covers the
/// map, so this closes it first.
void goToMapWithTarget(BuildContext context, NavigationTarget target) {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(navigationNotifierProvider.notifier).navigateToMapWithTarget(target);
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context);
  if (ModalRoute.of(context)?.settings is! Page && navigator.canPop()) {
    navigator.pop();
  }
  router.go(AppRoutes.map);
}

/// Cross-tab navigation commands waiting for the shell to act on them.
@freezed
abstract class NavigationState with _$NavigationState {
  const NavigationState._();

  const factory NavigationState({
    /// Target to show on the map tab.
    NavigationTarget? pendingNavigationTarget,

    /// Parcel to open on the forest tab.
    Parcel? pendingParcelToShow,

    /// Whether to open the search dialog on the map tab.
    @Default(false) bool shouldShowSearch,
  }) = _NavigationState;

  bool get isEmpty =>
      pendingNavigationTarget == null &&
      pendingParcelToShow == null &&
      !shouldShowSearch;
}

/// Handles cross-tab navigation commands for go_router.
class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() => const NavigationState();

  /// Navigate to map tab with a navigation target
  void navigateToMapWithTarget(NavigationTarget target) {
    state = state.copyWith(pendingNavigationTarget: target);
  }

  /// Navigate to forest tab and show parcel detail
  void navigateToForestWithParcel(Parcel parcel) {
    state = state.copyWith(pendingParcelToShow: parcel);
  }

  /// Navigate to map tab and show search dialog
  void navigateToMapWithSearch() {
    state = state.copyWith(shouldShowSearch: true);
  }

  /// Clear pending navigation target (call after handling)
  void clearNavigationTarget() {
    state = state.copyWith(pendingNavigationTarget: null);
  }

  /// Clear pending parcel (call after handling)
  void clearPendingParcel() {
    state = state.copyWith(pendingParcelToShow: null);
  }

  /// Clear search flag (call after handling)
  void clearSearchFlag() {
    state = state.copyWith(shouldShowSearch: false);
  }
}

final navigationNotifierProvider =
    NotifierProvider<NavigationNotifier, NavigationState>(
      NavigationNotifier.new,
    );

import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/distribution.dart';
import '../l10n/l10n.dart';
import '../router/app_router.dart';
import '../router/navigation_notifier.dart';
import '../screens/about_screen.dart';
import '../services/kataster_update_service.dart';
import '../services/onboarding_service.dart';
import '../services/update_service.dart';
import 'map_long_press_menu.dart';
import 'update_banner.dart';

/// Main scaffold with bottom navigation for the app shell
class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _tabTapCount = 0;

  NavigationDestination _buildNavigationDestination({
    required String semanticLabel,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    required bool selected,
  }) {
    return NavigationDestination(
      icon: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: ExcludeSemantics(child: Icon(icon)),
      ),
      selectedIcon: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: ExcludeSemantics(child: Icon(selectedIcon)),
      ),
      label: label,
      tooltip: semanticLabel,
    );
  }

  NavigationRailDestination _buildRailDestination({
    required String semanticLabel,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    required bool selected,
  }) {
    return NavigationRailDestination(
      icon: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: ExcludeSemantics(child: Icon(icon)),
      ),
      selectedIcon: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: ExcludeSemantics(child: Icon(selectedIcon)),
      ),
      label: Text(label),
    );
  }

  /// Build the list of tab definitions shared by both the bottom bar and rail.
  List<
    ({String semanticLabel, String label, IconData icon, IconData selectedIcon})
  >
  _tabDefinitions() {
    return [
      (
        semanticLabel: context.l10n.navTabSemantic(context.l10n.navTabMap),
        label: context.l10n.navTabMap,
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
      ),
      (
        semanticLabel: context.l10n.navTabSemantic(context.l10n.navTabForest),
        label: context.l10n.navTabForest,
        icon: Icons.park_outlined,
        selectedIcon: Icons.park,
      ),
      (
        semanticLabel: context.l10n.navTabSemantic(context.l10n.navTabLogs),
        label: context.l10n.navTabLogs,
        icon: Icons.forest_outlined,
        selectedIcon: Icons.forest,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    // Listen to navigation notifier for cross-tab navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A command sent before the shell existed.
      final pending = ref.read(navigationNotifierProvider);
      if (!pending.isEmpty) _handlePendingNavigation(pending);
      _checkKatasterUpdate();
    });
  }

  /// Weekly check for newer kataster data on R2 (the service rate-limits the
  /// network call); offers to re-download outdated regions via the about screen.
  Future<void> _checkKatasterUpdate() async {
    final update = await KatasterUpdateService.instance.check();
    if (update == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final mb = (update.bytes / (1024 * 1024)).toStringAsFixed(0);
    messenger.showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.map_outlined),
        content: Text(
          L10n.current.updateKatasterBanner(
            update.manifest.date ?? '',
            update.bytes > 0 ? ', ~$mb MB' : '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              KatasterUpdateService.instance.dismiss();
            },
            child: Text(L10n.current.updateLater),
          ),
          FilledButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              _showAboutScreen();
            },
            child: Text(L10n.current.updateNow),
          ),
        ],
      ),
    );
  }

  void _handlePendingNavigation(NavigationState pending) {
    final nav = ref.read(navigationNotifierProvider.notifier);

    // Handle pending navigation target (switch to map and set target)
    if (pending.pendingNavigationTarget != null) {
      widget.navigationShell.goBranch(0); // Switch to map tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = ref
            .read(navigationNotifierProvider)
            .pendingNavigationTarget;
        if (target == null) return;
        final map = mapTabKey.currentState;
        map?.setNavigationTarget(target);
        if (target.startNavigation) map?.showCompassForTarget();
        nav.clearNavigationTarget();
      });
    }

    // Handle pending parcel to show (switch to forest and open detail)
    if (pending.pendingParcelToShow != null) {
      widget.navigationShell.goBranch(1); // Switch to forest tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final parcel = ref.read(navigationNotifierProvider).pendingParcelToShow;
        if (parcel == null) return;
        forestTabKey.currentState?.openParcelDetail(parcel);
        nav.clearPendingParcel();
      });
    }

    // Handle search dialog request
    if (pending.shouldShowSearch) {
      widget.navigationShell.goBranch(0); // Switch to map tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!ref.read(navigationNotifierProvider).shouldShowSearch) return;
        mapTabKey.currentState?.showParcelSearchDialog();
        nav.clearSearchFlag();
      });
    }
  }

  void _handleTabTap(int index) {
    // Close the map's non-modal long-press sheet when leaving/switching tabs so
    // it doesn't linger over other tabs (it's anchored to the map Scaffold,
    // which stays alive in the IndexedStack).
    MapLongPressMenu.closeOpen();

    // Track consecutive taps on the same tab for easter eggs
    // Only count taps on already-selected tab
    if (index == widget.navigationShell.currentIndex) {
      _tabTapCount++;
      // 3 taps on any tab = show about screen
      if (_tabTapCount == 3) {
        _showAboutScreen();
      }
      // 5 taps on any tab = reset onboarding
      if (_tabTapCount >= 5) {
        _tabTapCount = 0;
        _resetOnboarding();
      }
    } else {
      // Switching to different tab resets counter
      _tabTapCount = 0;
    }

    // Navigate to the selected branch
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    // Refresh ForestTab when selected
    if (index == 1) {
      forestTabKey.currentState?.refresh();
    }
  }

  Future<void> _resetOnboarding() async {
    await OnboardingService.instance.resetOnboarding();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.navOnboardingReset),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showAboutScreen() {
    // Use root navigator to push outside shell
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => const AboutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Act on cross-tab navigation commands as they arrive.
    ref.listen(navigationNotifierProvider, (_, pending) {
      if (!pending.isEmpty) _handlePendingNavigation(pending);
    });

    final tabs = _tabDefinitions();
    final currentIndex = widget.navigationShell.currentIndex;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final body = Stack(
      children: [
        widget.navigationShell,
        // Update banner overlay (Android only)
        if (Platform.isAndroid && !isPlayDistribution)
          UpdateBanner(updateService: UpdateService()),
      ],
    );

    // In landscape, place the tab bar on the left as a NavigationRail to
    // reclaim vertical space. In portrait, keep the bottom NavigationBar.
    if (isLandscape) {
      return Scaffold(
        body: Row(
          children: [
            // Only the rail observes safe-area insets; the body stays full-bleed
            // so the map isn't padded away from the right edge.
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: currentIndex < tabs.length ? currentIndex : null,
                onDestinationSelected: _handleTabTap,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (var i = 0; i < tabs.length; i++)
                    _buildRailDestination(
                      semanticLabel: tabs[i].semanticLabel,
                      label: tabs[i].label,
                      icon: tabs[i].icon,
                      selectedIcon: tabs[i].selectedIcon,
                      selected: currentIndex == i,
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    final scaffold = Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < tabs.length ? currentIndex : 0,
        onDestinationSelected: _handleTabTap,
        destinations: [
          for (var i = 0; i < tabs.length; i++)
            _buildNavigationDestination(
              semanticLabel: tabs[i].semanticLabel,
              label: tabs[i].label,
              icon: tabs[i].icon,
              selectedIcon: tabs[i].selectedIcon,
              selected: currentIndex == i,
            ),
        ],
      ),
    );

    // iOS reserves a large bottom safe-area (home indicator) inset that pushes
    // both the map body and the nav bar up, leaving a dead gap. Strip it on iOS
    // so the map fills to the bottom and the nav bar sits flush at the edge.
    // Android keeps its gesture-nav inset.
    return Platform.isIOS
        ? MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: scaffold,
          )
        : scaffold;
  }
}

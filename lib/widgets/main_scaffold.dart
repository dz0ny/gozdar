import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/distribution.dart';
import '../router/app_router.dart';
import '../router/navigation_notifier.dart';
import '../screens/about_screen.dart';
import '../services/onboarding_service.dart';
import '../services/update_service.dart';
import 'update_banner.dart';

/// Main scaffold with bottom navigation for the app shell
class MainScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _tabTapCount = 0;
  NavigationNotifier? _navNotifier;

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
        child: ExcludeSemantics(
          child: Icon(icon),
        ),
      ),
      selectedIcon: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: Icon(selectedIcon),
        ),
      ),
      label: label,
      tooltip: semanticLabel,
    );
  }

  @override
  void initState() {
    super.initState();
    // Listen to navigation notifier for cross-tab navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingNavigation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<NavigationNotifier>();
    if (!identical(_navNotifier, notifier)) {
      _navNotifier?.removeListener(_handlePendingNavigation);
      _navNotifier = notifier;
      _navNotifier?.addListener(_handlePendingNavigation);
    }
  }

  @override
  void dispose() {
    _navNotifier?.removeListener(_handlePendingNavigation);
    super.dispose();
  }

  void _handlePendingNavigation() {
    final navNotifier = context.read<NavigationNotifier>();

    // Handle pending navigation target (switch to map and set target)
    if (navNotifier.pendingNavigationTarget != null) {
      widget.navigationShell.goBranch(0); // Switch to map tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapTabKey.currentState?.setNavigationTarget(
          navNotifier.pendingNavigationTarget!,
        );
        navNotifier.clearNavigationTarget();
      });
    }

    // Handle pending parcel to show (switch to forest and open detail)
    if (navNotifier.pendingParcelToShow != null) {
      widget.navigationShell.goBranch(1); // Switch to forest tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        forestTabKey.currentState?.openParcelDetail(
          navNotifier.pendingParcelToShow!,
        );
        navNotifier.clearPendingParcel();
      });
    }

    // Handle search dialog request
    if (navNotifier.shouldShowSearch) {
      widget.navigationShell.goBranch(0); // Switch to map tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapTabKey.currentState?.showParcelSearchDialog();
        navNotifier.clearSearchFlag();
      });
    }
  }

  void _handleTabTap(int index) {
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
        const SnackBar(
          content: Text(
            'Uvodni vodič ponastavljen. Ponovno zaženi aplikacijo.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showAboutScreen() {
    // Use root navigator to push outside shell
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => const AboutScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to navigation notifier changes
    context.watch<NavigationNotifier>();

    return Scaffold(
      body: Stack(
        children: [
          widget.navigationShell,
          // Update banner overlay (Android only)
          if (Platform.isAndroid && !isPlayDistribution)
            UpdateBanner(updateService: UpdateService()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _handleTabTap,
        destinations: [
          _buildNavigationDestination(
            semanticLabel: 'Tab Karta',
            label: 'Karta',
            icon: Icons.map_outlined,
            selectedIcon: Icons.map,
            selected: widget.navigationShell.currentIndex == 0,
          ),
          _buildNavigationDestination(
            semanticLabel: 'Tab Gozd',
            label: 'Gozd',
            icon: Icons.park_outlined,
            selectedIcon: Icons.park,
            selected: widget.navigationShell.currentIndex == 1,
          ),
          _buildNavigationDestination(
            semanticLabel: 'Tab Hlodi',
            label: 'Hlodi',
            icon: Icons.forest_outlined,
            selectedIcon: Icons.forest,
            selected: widget.navigationShell.currentIndex == 2,
          ),
        ],
      ),
    );
  }
}

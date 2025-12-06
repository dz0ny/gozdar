import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_tab.dart';
import 'screens/logs_tab.dart';
import 'screens/forest_tab.dart';
import 'screens/intro_wizard_screen.dart';
import 'services/database_service.dart';
import 'services/tile_cache_service.dart';
import 'services/onboarding_service.dart';
import 'services/update_service.dart';
import 'providers/logs_provider.dart';
import 'providers/map_provider.dart';
import 'theme/app_theme.dart';
import 'models/navigation_target.dart';
import 'widgets/update_banner.dart';
import 'widgets/worker_settings_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().initialize();
  await TileCacheService.initialize();
  await OnboardingService.initialize();

  // Initialize update service (Android only)
  if (Platform.isAndroid) {
    await UpdateService().init();
  }

  runApp(const GozdarApp());
}

class GozdarApp extends StatefulWidget {
  const GozdarApp({super.key});

  @override
  State<GozdarApp> createState() => _GozdarAppState();
}

class _GozdarAppState extends State<GozdarApp> {
  bool _showOnboarding = !OnboardingService.instance.isOnboardingCompleted;

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LogsProvider()..loadLogEntries()),
        ChangeNotifierProvider(
          create: (_) => MapProvider()
            ..loadPreferences()
            ..loadLocations()
            ..loadParcels(),
        ),
        if (Platform.isAndroid)
          ChangeNotifierProvider.value(value: UpdateService()),
      ],
      child: MaterialApp(
        title: 'Gozdar',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.greenTheme,
        home: _showOnboarding
            ? IntroWizardScreen(onComplete: _onOnboardingComplete)
            : MainScreen(key: MainScreen.globalKey),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// Global key to access MainScreenState from anywhere
  static final GlobalKey<MainScreenState> globalKey =
      GlobalKey<MainScreenState>();

  /// Navigate to map tab with a specific target location
  static void navigateToMapWithTarget(NavigationTarget target) {
    globalKey.currentState?.setNavigationTarget(target);
  }

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // Start on Gozd (Forest) tab
  int _tabTapCount = 0;
  int? _lastTappedTab;

  // GlobalKey to access ForestTab state for refresh
  final GlobalKey<ForestTabState> _forestTabKey = GlobalKey<ForestTabState>();
  // GlobalKey to access MapTab state for navigation
  final GlobalKey<MapTabState> _mapTabKey = GlobalKey<MapTabState>();

  @override
  void initState() {
    super.initState();
    // Check for updates on startup (Android only)
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UpdateService().checkForUpdate();
      });
    }
  }

  /// Set navigation target and switch to map tab
  void setNavigationTarget(NavigationTarget target) {
    // Update provider state
    context.read<MapProvider>().setNavigationTarget(target);

    setState(() {
      _currentIndex = 0; // Switch to map tab
    });
    // Set the target on the map tab after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapTabKey.currentState?.setNavigationTarget(target);
    });
  }

  void _handleTabTap(int index) {
    // Track consecutive taps on the same tab
    if (index == _lastTappedTab && index == _currentIndex) {
      _tabTapCount++;
      // 3 taps on Karta tab = show worker settings dialog
      if (_tabTapCount >= 3 && index == 0) {
        _tabTapCount = 0;
        _showWorkerSettingsDialog();
      }
      // 5 taps on any tab = reset onboarding
      else if (_tabTapCount >= 5) {
        _tabTapCount = 0;
        _resetOnboarding();
      }
    } else {
      _tabTapCount = 1;
      _lastTappedTab = index;
    }

    setState(() {
      _currentIndex = index;
    });

    // Refresh ForestTab when selected
    if (index == 1) {
      _forestTabKey.currentState?.refresh();
    }
  }

  void _showWorkerSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => WorkerSettingsDialog(
        onOpenDownload: () {
          _mapTabKey.currentState?.showTileDownloadDialog();
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: MapTab(key: _mapTabKey),
              ),
              MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: ForestTab(key: _forestTabKey),
              ),
              MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: const LogsTab(),
              ),
            ],
          ),
          // Update banner overlay (Android only)
          if (Platform.isAndroid) UpdateBanner(updateService: UpdateService()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _handleTabTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Karta',
          ),
          NavigationDestination(
            icon: Icon(Icons.park_outlined),
            selectedIcon: Icon(Icons.park),
            label: 'Gozd',
          ),
          NavigationDestination(
            icon: Icon(Icons.forest_outlined),
            selectedIcon: Icon(Icons.forest),
            label: 'Hlodi',
          ),
        ],
      ),
    );
  }
}

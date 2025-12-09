import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
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
import 'models/parcel.dart';
import 'widgets/update_banner.dart';
import 'widgets/worker_settings_dialog.dart';
import 'services/analytics_service.dart';

/// Firebase Analytics instance for tracking app usage (may be null if Firebase not configured)
FirebaseAnalytics? _analytics;
FirebaseAnalytics? get analytics => _analytics;

/// Global analytics service instance
final analyticsService = AnalyticsService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only in release mode (skip for debug builds)
  if (!kDebugMode) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _analytics = FirebaseAnalytics.instance;

      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      // Continue without Firebase - analytics and crashlytics will be null
    }
  } else {
    debugPrint('Firebase disabled in debug mode');
  }

  await DatabaseService().initialize();
  await TileCacheService.initialize();
  await OnboardingService.initialize();

  // Initialize update service (Android only)
  if (Platform.isAndroid) {
    await UpdateService().init();
  }

  // Log app start
  analyticsService.logAppStart();

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
            ..loadParcels()
            ..loadGeolocatedLogs(),
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

  /// Navigate to forest tab and show a specific parcel
  static void navigateToForestWithParcel(Parcel parcel) {
    globalKey.currentState?.showParcelInForestTab(parcel);
  }

  /// Navigate to map tab and trigger search dialog
  static void navigateToMapWithSearch() {
    globalKey.currentState?.switchToMapAndSearch();
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

  /// Navigate to forest tab and show specific parcel detail
  void showParcelInForestTab(Parcel parcel) {
    setState(() {
      _currentIndex = 1; // Switch to forest tab
    });
    // Open parcel detail after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forestTabKey.currentState?.openParcelDetail(parcel);
    });
  }

  /// Navigate to map tab and show parcel search dialog
  void switchToMapAndSearch() {
    setState(() {
      _currentIndex = 0; // Switch to Karta (Map) tab
    });

    // Show search dialog after tab switch completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapTabKey.currentState?.showParcelSearchDialog();
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

    // Track tab switch
    final tabNames = [
      AnalyticsService.screenMap,
      AnalyticsService.screenForest,
      AnalyticsService.screenLogs,
    ];
    analyticsService.logTabSwitched(tabName: tabNames[index]);
    analyticsService.logScreenView(tabNames[index]);

    // Refresh ForestTab when selected
    if (index == 1) {
      _forestTabKey.currentState?.refresh();
    }
  }

  void _showWorkerSettingsDialog() {
    analyticsService.logWorkerSettingsOpened();
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
    analyticsService.logOnboardingReset();
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

import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'router/navigation_notifier.dart';
import 'services/database_service.dart';
import 'services/tile_cache_service.dart';
import 'services/onboarding_service.dart';
import 'services/update_service.dart';
import 'providers/logs_provider.dart';
import 'providers/map_provider.dart';
import 'theme/app_theme.dart';
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
  late final NavigationNotifier _navigationNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _navigationNotifier = NavigationNotifier();
    _router = createRouter(
      showOnboarding: !OnboardingService.instance.isOnboardingCompleted,
    );

    // Check for updates on startup (Android only)
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UpdateService().checkForUpdate();
      });
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
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
        ChangeNotifierProvider.value(value: _navigationNotifier),
        if (Platform.isAndroid)
          ChangeNotifierProvider.value(value: UpdateService()),
      ],
      child: MaterialApp.router(
        title: 'Gozdar',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.greenTheme,
        routerConfig: _router,
      ),
    );
  }
}

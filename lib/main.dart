import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'router/app_router.dart';
import 'router/navigation_notifier.dart';
import 'services/database_service.dart';
import 'services/tile_cache_service.dart';
import 'services/onboarding_service.dart';
import 'services/update_service.dart';
import 'providers/logs_provider.dart';
import 'providers/map_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Aptabase analytics
  await Aptabase.init('A-EU-0504687602');

  await DatabaseService().initialize();
  await TileCacheService.initialize();
  await OnboardingService.initialize();

  // Initialize update service (Android only)
  if (Platform.isAndroid) {
    await UpdateService().init();
  }

  // Track app start
  Aptabase.instance.trackEvent('app_start');

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

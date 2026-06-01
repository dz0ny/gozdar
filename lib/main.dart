import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'config/distribution.dart';
import 'router/app_router.dart';
import 'router/navigation_notifier.dart';
import 'services/database_service.dart';
import 'services/rtk_bridge_settings.dart';
import 'services/tile_cache_service.dart';
import 'services/onboarding_service.dart';
import 'services/owner_lookup_service.dart';
import 'services/parcel_lookup_service.dart';
import 'services/owner_offline_settings_service.dart';
import 'services/update_service.dart';
import 'services/vlake_settings.dart';
import 'providers/logs_provider.dart';
import 'providers/map_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseService().initialize();
  await TileCacheService.initialize();
  await OnboardingService.initialize();
  await RtkBridgeSettings.instance.load();
  await OwnerLookupService.instance.init();
  await ParcelLookupService.instance.init();
  await OwnerOfflineSettingsService.instance.init();
  await VlakeSettings.instance.load();

  // Initialize update service (Android only)
  if (Platform.isAndroid && !isPlayDistribution) {
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
  static const _initialRouteDefine = String.fromEnvironment(
    'GOZDAR_INITIAL_ROUTE',
  );
  late final NavigationNotifier _navigationNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _navigationNotifier = NavigationNotifier();
    final initialRoute = _initialRouteDefine.isEmpty ? null : _initialRouteDefine;
    _router = createRouter(
      showOnboarding: !OnboardingService.instance.isOnboardingCompleted,
      initialLocation: initialRoute,
    );

    // Check for updates on startup (Android only)
    if (Platform.isAndroid && !isPlayDistribution) {
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
        ChangeNotifierProvider.value(value: RtkBridgeSettings.instance),
        ChangeNotifierProvider.value(value: VlakeSettings.instance),
        if (Platform.isAndroid && !isPlayDistribution)
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

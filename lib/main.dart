import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'config/distribution.dart';
import 'router/app_router.dart';
import 'router/navigation_notifier.dart';
import 'services/database_service.dart';
import 'services/tile_cache_service.dart';
import 'services/onboarding_service.dart';
import 'services/update_service.dart';
import 'providers/logs_provider.dart';
import 'providers/map_provider.dart';
import 'screens/play_asset_preview_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final playAssetPreview = Platform.environment['GOZDAR_PLAY_ASSET_PREVIEW'];
  if (playAssetPreview != null && playAssetPreview.isNotEmpty) {
    runApp(
      PlayAssetPreviewApp(
        kind: playAssetPreview,
        outputPath: Platform.environment['GOZDAR_PLAY_ASSET_OUTPUT'],
      ),
    );
    return;
  }

  await DatabaseService().initialize();
  await TileCacheService.initialize();
  await OnboardingService.initialize();

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

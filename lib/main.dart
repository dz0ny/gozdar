import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/distribution.dart';
import 'router/app_router.dart';
import 'services/database_service.dart';
import 'services/tile_cache_service.dart';
import 'services/onboarding_service.dart';
import 'services/address_lookup_service.dart';
import 'services/owner_lookup_service.dart';
import 'services/parcel_lookup_service.dart';
import 'services/kataster_update_service.dart';
import 'services/cache_settings.dart';
import 'services/public_parcel_settings.dart';
import 'services/drone_settings.dart';
import 'services/owner_offline_settings_service.dart';
import 'services/update_service.dart';
import 'services/auction_service.dart';
import 'services/vlake_settings.dart';
import 'services/locale_settings.dart';
import 'l10n/l10n.dart';
import 'services/secnja_share_flow.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseService().initialize();
  await TileCacheService.initialize();
  await OnboardingService.initialize();
  await OwnerLookupService.instance.init();
  await OwnerLookupService.instance.initPublic();
  await ParcelLookupService.instance.init();
  OwnerLookupService.instance.initPublicHr().ignore();
  await AddressLookupService.instance.init();
  await KatasterUpdateService.instance.init();
  await OwnerOfflineSettingsService.instance.init();
  await DroneSettings.instance.init();
  await CacheSettings.instance.load();
  await PublicParcelSettings.instance.load();
  await AuctionService.instance.loadSettings();
  await initializeDateFormatting();

  // Initialize update service (Android only)
  if (Platform.isAndroid && !isPlayDistribution) {
    await UpdateService().init();
  }

  // Settings the first frame needs, read before it.
  final container = ProviderContainer();
  await container.read(vlakeSettingsProvider.notifier).load();
  await container.read(localeSettingsProvider.notifier).load();

  runApp(
    UncontrolledProviderScope(container: container, child: const GozdarApp()),
  );
}

class GozdarApp extends ConsumerStatefulWidget {
  const GozdarApp({super.key});

  @override
  ConsumerState<GozdarApp> createState() => _GozdarAppState();
}

class _GozdarAppState extends ConsumerState<GozdarApp>
    with WidgetsBindingObserver {
  /// Messages from work outside a screen, e.g. imported sečnja updates.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  DateTime? _sharesCheckedAt;

  static const _initialRouteDefine = String.fromEnvironment(
    'GOZDAR_INITIAL_ROUTE',
  );
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final initialRoute = _initialRouteDefine.isEmpty
        ? null
        : _initialRouteDefine;
    _router = createRouter(
      showOnboarding: !OnboardingService.instance.isOnboardingCompleted,
      initialLocation: initialRoute,
    );

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkImportedShares());

    // Check for updates on startup (Android only)
    if (Platform.isAndroid && !isPlayDistribution) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UpdateService().checkForUpdate();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkImportedShares();
  }

  /// Picks up the owner's changes to imported sečnja lists, at most every
  /// five minutes.
  Future<void> _checkImportedShares() async {
    final now = DateTime.now();
    final last = _sharesCheckedAt;
    if (last != null && now.difference(last) < const Duration(minutes: 5)) {
      return;
    }
    _sharesCheckedAt = now;
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    try {
      await refreshImportedSecnja(messenger.context, messenger: messenger);
    } catch (e) {
      debugPrint('Imported share check failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeSettingsProvider);
    return MaterialApp.router(
      title: 'Gozdar',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.greenTheme,
      routerConfig: _router,
      locale: locale,
      supportedLocales: const [Locale('sl'), Locale('hr')],
      localizationsDelegates: appLocalizationsDelegates,
      localeResolutionCallback: (locale, supported) => L10n.resolve(locale),
    );
  }
}

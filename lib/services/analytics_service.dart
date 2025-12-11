import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_analytics/firebase_analytics.dart';
import '../main.dart' show analytics;

/// Centralized analytics service for tracking app usage
/// Uses Firebase Analytics when available, gracefully handles missing config
/// Analytics are automatically disabled in debug mode to avoid polluting production data
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? get _analytics => kDebugMode ? null : analytics;

  // Screen names for consistent tracking
  static const screenMap = 'karta';
  static const screenForest = 'gozd';
  static const screenLogs = 'hlodi';
  static const screenParcelDetail = 'parcel_detail';
  static const screenBatchDetail = 'batch_detail';
  static const screenOnboarding = 'onboarding';

  /// Log screen view
  Future<void> logScreenView(String screenName) async {
    await _analytics?.logScreenView(screenName: screenName);
  }

  // --- Parcel Events ---

  /// Log parcel added manually
  Future<void> logParcelAdded({double? areaMSquared}) async {
    await _analytics?.logEvent(
      name: 'parcel_added',
      parameters: {
        if (areaMSquared != null) 'area_m2': areaMSquared,
      },
    );
  }

  /// Log parcel imported from KML file
  Future<void> logParcelImportedKml({int count = 1}) async {
    await _analytics?.logEvent(
      name: 'parcel_imported_kml',
      parameters: {'count': count},
    );
  }

  /// Log parcel imported from cadastral service
  Future<void> logParcelImportedCadastral() async {
    await _analytics?.logEvent(name: 'parcel_imported_cadastral');
  }

  /// Log parcel imported from WFS service
  Future<void> logParcelImportedWfs() async {
    await _analytics?.logEvent(name: 'parcel_imported_wfs');
  }

  /// Log parcel deleted
  Future<void> logParcelDeleted() async {
    await _analytics?.logEvent(name: 'parcel_deleted');
  }

  /// Log parcel detail viewed
  Future<void> logParcelViewed() async {
    await _analytics?.logEvent(name: 'parcel_viewed');
  }

  /// Log parcel exported to KML
  Future<void> logParcelExportedKml({int count = 1}) async {
    await _analytics?.logEvent(
      name: 'parcel_exported_kml',
      parameters: {'count': count},
    );
  }

  // --- Log Entry Events ---

  /// Log entry added
  Future<void> logLogAdded({double? volumeM3, bool hasLocation = false}) async {
    await _analytics?.logEvent(
      name: 'log_added',
      parameters: {
        if (volumeM3 != null) 'volume_m3': volumeM3,
        'has_location': hasLocation ? 1 : 0,
      },
    );
  }

  /// Log entry edited
  Future<void> logLogEdited() async {
    await _analytics?.logEvent(name: 'log_edited');
  }

  /// Log entry deleted
  Future<void> logLogDeleted() async {
    await _analytics?.logEvent(name: 'log_deleted');
  }

  /// Log all entries deleted
  Future<void> logLogsAllDeleted({int count = 0}) async {
    await _analytics?.logEvent(
      name: 'logs_all_deleted',
      parameters: {'count': count},
    );
  }

  /// Log entries exported
  Future<void> logLogsExported({required String format, int count = 0}) async {
    await _analytics?.logEvent(
      name: 'logs_exported',
      parameters: {
        'format': format,
        'count': count,
      },
    );
  }

  /// Log batch saved
  Future<void> logBatchSaved({int logCount = 0, double totalVolume = 0}) async {
    await _analytics?.logEvent(
      name: 'batch_saved',
      parameters: {
        'log_count': logCount,
        'volume_m3': totalVolume,
      },
    );
  }

  /// Log batch viewed
  Future<void> logBatchViewed() async {
    await _analytics?.logEvent(name: 'batch_viewed');
  }

  /// Log batch exported
  Future<void> logBatchExported({required String format}) async {
    await _analytics?.logEvent(
      name: 'batch_exported',
      parameters: {'format': format},
    );
  }

  // --- Map Events ---

  /// Log location marker added
  Future<void> logLocationAdded() async {
    await _analytics?.logEvent(name: 'location_added');
  }

  /// Log secnja marker added
  Future<void> logSecnjaAdded() async {
    await _analytics?.logEvent(name: 'secnja_added');
  }

  /// Log location deleted
  Future<void> logLocationDeleted() async {
    await _analytics?.logEvent(name: 'location_deleted');
  }

  /// Log map layer changed
  Future<void> logMapLayerChanged({required String layerName}) async {
    await _analytics?.logEvent(
      name: 'map_layer_changed',
      parameters: {'layer': layerName},
    );
  }

  /// Log overlay toggled
  Future<void> logMapOverlayToggled({
    required String overlayName,
    required bool enabled,
  }) async {
    await _analytics?.logEvent(
      name: 'map_overlay_toggled',
      parameters: {
        'overlay': overlayName,
        'enabled': enabled ? 1 : 0,
      },
    );
  }

  /// Log GPS location centered
  Future<void> logGpsCentered() async {
    await _analytics?.logEvent(name: 'gps_centered');
  }

  /// Log navigation target set
  Future<void> logNavigationStarted() async {
    await _analytics?.logEvent(name: 'navigation_started');
  }

  /// Log compass dialog opened
  Future<void> logCompassOpened() async {
    await _analytics?.logEvent(name: 'compass_opened');
  }

  /// Log tiles downloaded for offline use
  Future<void> logTilesDownloaded({int tileCount = 0}) async {
    await _analytics?.logEvent(
      name: 'tiles_downloaded',
      parameters: {'count': tileCount},
    );
  }

  // --- Onboarding Events ---

  /// Log onboarding completed
  Future<void> logOnboardingCompleted() async {
    await _analytics?.logEvent(name: 'onboarding_completed');
  }

  /// Log onboarding skipped
  Future<void> logOnboardingSkipped({int pageIndex = 0}) async {
    await _analytics?.logEvent(
      name: 'onboarding_skipped',
      parameters: {'page': pageIndex},
    );
  }

  /// Log onboarding reset
  Future<void> logOnboardingReset() async {
    await _analytics?.logEvent(name: 'onboarding_reset');
  }

  // --- App Events ---

  /// Log app started
  Future<void> logAppStart() async {
    await _analytics?.logEvent(name: 'app_start');
  }

  /// Log tab switched
  Future<void> logTabSwitched({required String tabName}) async {
    await _analytics?.logEvent(
      name: 'tab_switched',
      parameters: {'tab': tabName},
    );
  }

  /// Log owner filter applied
  Future<void> logOwnerFilterApplied({required bool hasFilter}) async {
    await _analytics?.logEvent(
      name: 'owner_filter_applied',
      parameters: {'has_filter': hasFilter ? 1 : 0},
    );
  }

  /// Log conversion settings changed
  Future<void> logConversionSettingsChanged() async {
    await _analytics?.logEvent(name: 'conversion_settings_changed');
  }
}

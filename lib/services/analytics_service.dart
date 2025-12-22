import 'package:aptabase_flutter/aptabase_flutter.dart';

/// Centralized analytics service for tracking app usage
/// Uses Aptabase for privacy-first analytics
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Screen names for consistent tracking
  static const screenMap = 'karta';
  static const screenForest = 'gozd';
  static const screenLogs = 'hlodi';
  static const screenParcelDetail = 'parcel_detail';
  static const screenBatchDetail = 'batch_detail';
  static const screenOnboarding = 'onboarding';

  void _track(String event, [Map<String, dynamic>? props]) {
    Aptabase.instance.trackEvent(event, props);
  }

  Future<void> logScreenView(String screenName) async {
    _track('screen_view', {'screen': screenName});
  }

  // --- Parcel Events ---

  Future<void> logParcelAdded({double? areaMSquared}) async {
    _track('parcel_added', {if (areaMSquared != null) 'area_m2': areaMSquared});
  }

  Future<void> logParcelImportedKml({int count = 1}) async {
    _track('parcel_imported_kml', {'count': count});
  }

  Future<void> logParcelImportedCadastral() async {
    _track('parcel_imported_cadastral');
  }

  Future<void> logParcelImportedWfs() async {
    _track('parcel_imported_wfs');
  }

  Future<void> logParcelDeleted() async {
    _track('parcel_deleted');
  }

  Future<void> logParcelViewed() async {
    _track('parcel_viewed');
  }

  Future<void> logParcelExportedKml({int count = 1}) async {
    _track('parcel_exported_kml', {'count': count});
  }

  // --- Log Entry Events ---

  Future<void> logLogAdded({double? volumeM3, bool hasLocation = false}) async {
    _track('log_added', {
      if (volumeM3 != null) 'volume_m3': volumeM3,
      'has_location': hasLocation ? 1 : 0,
    });
  }

  Future<void> logLogEdited() async {
    _track('log_edited');
  }

  Future<void> logLogDeleted() async {
    _track('log_deleted');
  }

  Future<void> logLogsAllDeleted({int count = 0}) async {
    _track('logs_all_deleted', {'count': count});
  }

  Future<void> logLogsExported({required String format, int count = 0}) async {
    _track('logs_exported', {'format': format, 'count': count});
  }

  Future<void> logBatchSaved({int logCount = 0, double totalVolume = 0}) async {
    _track('batch_saved', {'log_count': logCount, 'volume_m3': totalVolume});
  }

  Future<void> logBatchViewed() async {
    _track('batch_viewed');
  }

  Future<void> logBatchExported({required String format}) async {
    _track('batch_exported', {'format': format});
  }

  // --- Map Events ---

  Future<void> logLocationAdded() async {
    _track('location_added');
  }

  Future<void> logSecnjaAdded() async {
    _track('secnja_added');
  }

  Future<void> logLocationDeleted() async {
    _track('location_deleted');
  }

  Future<void> logMapLayerChanged({required String layerName}) async {
    _track('map_layer_changed', {'layer': layerName});
  }

  Future<void> logMapOverlayToggled({
    required String overlayName,
    required bool enabled,
  }) async {
    _track('map_overlay_toggled', {
      'overlay': overlayName,
      'enabled': enabled ? 1 : 0,
    });
  }

  Future<void> logGpsCentered() async {
    _track('gps_centered');
  }

  Future<void> logNavigationStarted() async {
    _track('navigation_started');
  }

  Future<void> logCompassOpened() async {
    _track('compass_opened');
  }

  Future<void> logTilesDownloaded({int tileCount = 0}) async {
    _track('tiles_downloaded', {'count': tileCount});
  }

  // --- Onboarding Events ---

  Future<void> logOnboardingCompleted() async {
    _track('onboarding_completed');
  }

  Future<void> logOnboardingSkipped({int pageIndex = 0}) async {
    _track('onboarding_skipped', {'page': pageIndex});
  }

  Future<void> logOnboardingReset() async {
    _track('onboarding_reset');
  }

  // --- App Events ---

  Future<void> logAppStart() async {
    _track('app_start');
  }

  Future<void> logTabSwitched({required String tabName}) async {
    _track('tab_switched', {'tab': tabName});
  }

  Future<void> logOwnerFilterApplied({required bool hasFilter}) async {
    _track('owner_filter_applied', {'has_filter': hasFilter ? 1 : 0});
  }

  Future<void> logConversionSettingsChanged() async {
    _track('conversion_settings_changed');
  }
}

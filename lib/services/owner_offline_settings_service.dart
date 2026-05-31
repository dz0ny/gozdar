import 'package:shared_preferences/shared_preferences.dart';

/// Persisted toggle for offline owner reverse lookup from the local parcel
/// bounding-box geometry in the imported owners database.
///
/// On by default. Used only as a fallback when the online cadastral lookup is
/// unavailable. Stored in shared preferences so the choice survives app
/// restarts. Mirrors the lightweight singleton style of other settings here.
class OwnerOfflineSettingsService {
  OwnerOfflineSettingsService._();
  static final OwnerOfflineSettingsService instance =
      OwnerOfflineSettingsService._();

  static const _key = 'offline_owner_lookup';
  bool _enabled = true;

  bool get enabled => _enabled;

  /// Load the persisted value. Call once during app startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? true;
  }

  /// Persist and update the in-memory value.
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = value;
    await prefs.setBool(_key, value);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted opt-in for the experimental drone survey tools (mission export).
///
/// Off by default so the feature stays out of the way for other users.
class DroneSettings {
  DroneSettings._();
  static final DroneSettings instance = DroneSettings._();

  static const _key = 'drone_tools_enabled';
  bool _enabled = false;

  bool get enabled => _enabled;

  /// Load the persisted value. Call once during app startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = value;
    await prefs.setBool(_key, value);
  }
}

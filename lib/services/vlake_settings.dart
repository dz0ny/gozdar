import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted toggle for the embedded Vlake (forest skid-road) overlay.
/// Exposed via the hidden developer sheet in the About screen.
class VlakeSettings extends ChangeNotifier {
  VlakeSettings._();

  static const _enabledKey = 'vlake.enabled';
  static final instance = VlakeSettings._();

  bool _enabled = false;

  bool get enabled => _enabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;

    _enabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
}

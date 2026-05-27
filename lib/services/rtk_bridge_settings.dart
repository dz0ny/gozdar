import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RtkBridgeSettings extends ChangeNotifier {
  RtkBridgeSettings._();

  static const _enabledKey = 'rtk.bridgeEnabled';
  static final instance = RtkBridgeSettings._();

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

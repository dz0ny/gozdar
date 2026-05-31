import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted state for the embedded Vlake (forest skid-road) overlay.
///
/// Two flags: [enabled] is the hidden developer unlock (set from the About
/// screen) that makes the layer available; [visible] is the per-layer on/off
/// the user controls from the map layer selector. The overlay is drawn only
/// when [showOnMap] (both true).
class VlakeSettings extends ChangeNotifier {
  VlakeSettings._();

  static const _enabledKey = 'vlake.enabled';
  static const _visibleKey = 'vlake.visible';
  static final instance = VlakeSettings._();

  bool _enabled = false;
  bool _visible = true;

  /// Developer unlock: whether the Vlake layer is available at all.
  bool get enabled => _enabled;

  /// User toggle (layer selector): whether the layer is shown when available.
  bool get visible => _visible;

  /// Whether the overlay should actually be drawn on the map.
  bool get showOnMap => _enabled && _visible;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _visible = prefs.getBool(_visibleKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;

    _enabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setVisible(bool visible) async {
    if (_visible == visible) return;

    _visible = visible;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visibleKey, visible);
  }
}

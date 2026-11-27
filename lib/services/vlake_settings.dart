import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'vlake_settings.freezed.dart';

/// Persisted state for the embedded Vlake (forest skid-road) overlay.
///
/// Two flags: [enabled] is the hidden developer unlock (set from the About
/// screen) that makes the layer available; [visible] is the per-layer on/off
/// the user controls from the map layer selector. The overlay is drawn only
/// when [showOnMap] (both true).
@freezed
abstract class VlakeState with _$VlakeState {
  const VlakeState._();

  const factory VlakeState({
    /// Developer unlock: whether the Vlake layer is available at all.
    @Default(false) bool enabled,

    /// User toggle (layer selector): whether the layer is shown when available.
    @Default(true) bool visible,
  }) = _VlakeState;

  /// Whether the overlay should actually be drawn on the map.
  bool get showOnMap => enabled && visible;
}

class VlakeSettings extends Notifier<VlakeState> {
  static const _enabledKey = 'vlake.enabled';
  static const _visibleKey = 'vlake.visible';

  @override
  VlakeState build() => const VlakeState();

  /// Reads the saved flags; main() awaits it before the first frame.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = VlakeState(
      enabled: prefs.getBool(_enabledKey) ?? false,
      visible: prefs.getBool(_visibleKey) ?? true,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (state.enabled == enabled) return;
    state = state.copyWith(enabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setVisible(bool visible) async {
    if (state.visible == visible) return;
    state = state.copyWith(visible: visible);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visibleKey, visible);
  }
}

final vlakeSettingsProvider = NotifierProvider<VlakeSettings, VlakeState>(
  VlakeSettings.new,
);

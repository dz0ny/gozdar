import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// User-selected UI language. `null` follows the device language
/// (Croatian on hr devices, Slovenian otherwise).
class LocaleSettings extends Notifier<Locale?> {
  static const _key = 'app_locale';

  @override
  Locale? build() => null;

  /// Reads the saved choice; main() awaits it before the first frame.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    state = code == null ? null : Locale(code);
    _sync();
  }

  Future<void> setOverride(Locale? locale) async {
    state = locale;
    _sync();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }

  void _sync() => L10n.setLocale(
    state ?? WidgetsBinding.instance.platformDispatcher.locale,
  );
}

final localeSettingsProvider = NotifierProvider<LocaleSettings, Locale?>(
  LocaleSettings.new,
);

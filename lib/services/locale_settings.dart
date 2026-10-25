import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// User-selected UI language. `null` follows the device language
/// (Croatian on hr devices, Slovenian otherwise).
class LocaleSettings extends ChangeNotifier {
  LocaleSettings._();
  static final LocaleSettings instance = LocaleSettings._();

  static const _key = 'app_locale';

  Locale? _override;
  Locale? get override => _override;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    _override = code == null ? null : Locale(code);
    _sync();
  }

  Future<void> setOverride(Locale? locale) async {
    _override = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    _sync();
    notifyListeners();
  }

  void _sync() => L10n.setLocale(
    _override ?? WidgetsBinding.instance.platformDispatcher.locale,
  );
}

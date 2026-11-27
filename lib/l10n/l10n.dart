import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Delegates for the app's MaterialApp. The generated
/// [AppLocalizations.localizationsDelegates] still names the old Material and
/// Cupertino localizations, which material_ui widgets don't look up.
const appLocalizationsDelegates = <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Access to the active translations from code without a [BuildContext]
/// (services, models). Kept in sync with the app locale by [LocaleSettings].
class L10n {
  L10n._();

  static AppLocalizations _current = lookupAppLocalizations(const Locale('sl'));

  static AppLocalizations get current => _current;

  static void setLocale(Locale locale) {
    _current = lookupAppLocalizations(resolve(locale));
  }

  /// Croatian when requested, Slovenian for everything else.
  static Locale resolve(Locale? locale) =>
      locale?.languageCode == 'hr' ? const Locale('hr') : const Locale('sl');
}

import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Access to the active translations from code without a [BuildContext]
/// (services, models). Kept in sync with the app locale by [LocaleSettings].
class L10n {
  L10n._();

  static AppLocalizations _current = lookupAppLocalizations(
    const Locale('sl'),
  );

  static AppLocalizations get current => _current;

  static void setLocale(Locale locale) {
    _current = lookupAppLocalizations(resolve(locale));
  }

  /// Croatian when requested, Slovenian for everything else.
  static Locale resolve(Locale? locale) =>
      locale?.languageCode == 'hr' ? const Locale('hr') : const Locale('sl');
}

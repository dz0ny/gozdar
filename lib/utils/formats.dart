import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

/// Locale-aware display formatting (decimal comma, thousands dot for sl/hr).
/// Use for anything shown to the user; keep `toStringAsFixed` for exports,
/// URLs and other machine-readable output.
class Fmt {
  Fmt._();

  static String get _locale => L10n.current.localeName;

  /// [value] with exactly [decimals] fraction digits, e.g. `num(6.07, 2)` → "6,07".
  static String num(double value, [int decimals = 2]) =>
      NumberFormat.decimalPatternDigits(
        locale: _locale,
        decimalDigits: decimals,
      ).format(value);

  /// Solid volume in m³ with 2 decimals, e.g. "0,38 m³".
  static String m3(double value, [int decimals = 2]) =>
      '${num(value, decimals)} m³';

  /// Area as ha above one hectare, m² below, e.g. "6,07 ha" / "3.535 m²".
  static String area(double m2) =>
      m2 >= 10000 ? '${num(m2 / 10000, 2)} ha' : '${num(m2, 0)} m²';

  /// Calendar date, e.g. "31. 10. 2026".
  static String date(DateTime d) => DateFormat('d. M. yyyy', _locale).format(d);

  /// Date and time, e.g. "31. 10. 2026 10:49".
  static String dateTime(DateTime d) =>
      DateFormat('d. M. yyyy HH:mm', _locale).format(d);
}

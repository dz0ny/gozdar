import 'package:flutter/services.dart';

/// Accepts digits with at most one decimal separator, allowing both '.' and
/// ',' — Slovenian numeric keyboards often only offer the comma.
class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    return RegExp(r'^\d*[.,]?\d*$').hasMatch(newValue.text)
        ? newValue
        : oldValue;
  }
}

/// Parses [input] treating ',' as a decimal point. Returns null when invalid.
double? parseDecimal(String input) =>
    double.tryParse(input.trim().replaceAll(',', '.'));

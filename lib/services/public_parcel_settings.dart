import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Category of a publicly owned/managed parcel, by owner type. Each carries a
/// map colour and a Slovenian label used by the long-press toggles.
enum PublicOwnerCategory {
  state('Država', Color(0xFF1565C0)), // Republika Slovenija
  obcina('Občina', Color(0xFF2E7D32)), // municipalities
  company('Podjetje', Color(0xFFEF6C00)); // other legal entities

  const PublicOwnerCategory(this.label, this.color);

  /// Outline colour for parcels of this category.
  final Color color;
  final String label;

  /// Faint fill so the parcel interior is tinted but imagery still reads.
  Color get fillColor => color.withValues(alpha: 0.13);

  String get _prefKey => 'public_cat_$name';
}

/// Which public-owner categories are highlighted on the map. Per-category
/// on/off, toggled from the long-press menu; empty means no highlighting (all
/// parcels stay the default red).
class PublicParcelSettings {
  PublicParcelSettings._();
  static final PublicParcelSettings instance = PublicParcelSettings._();

  final Set<PublicOwnerCategory> _on = {};

  bool isOn(PublicOwnerCategory c) => _on.contains(c);
  bool get anyOn => _on.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _on.clear();
    for (final c in PublicOwnerCategory.values) {
      if (prefs.getBool(c._prefKey) ?? false) _on.add(c);
    }
  }

  Future<void> setOn(PublicOwnerCategory c, bool value) async {
    if (value) {
      _on.add(c);
    } else {
      _on.remove(c);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(c._prefKey, value);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Whether offline kataster parcels that are publicly owned/managed (present in
/// the embedded public-owners DB: state, municipalities, companies, managers)
/// are drawn in a distinct colour from privately owned ones.
class PublicParcelSettings {
  PublicParcelSettings._();
  static final PublicParcelSettings instance = PublicParcelSettings._();

  static const _key = 'highlight_public_parcels';
  bool _enabled = false;

  bool get enabled => _enabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

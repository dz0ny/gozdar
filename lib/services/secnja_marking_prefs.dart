import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the species chip of the sečnja marking mode between sessions.
class SecnjaMarkingPrefs {
  static const _key = 'secnja_marking_species';

  Future<String?> getSpecies() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  Future<void> setSpecies(String? species) async {
    final prefs = await SharedPreferences.getInstance();
    if (species == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, species);
    }
  }
}

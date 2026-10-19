import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last values used when adding logs in the Hlodi tab:
/// diameter, length and the species that new logs are assigned to.
class LogInputPrefsService {
  static const String _keyDiameter = 'log_input_last_diameter';
  static const String _keyLength = 'log_input_last_length';
  static const String _keySpecies = 'log_input_current_species';

  Future<double?> getLastDiameter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyDiameter);
  }

  Future<double?> getLastLength() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyLength);
  }

  Future<void> saveLastDimensions(double diameter, double length) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyDiameter, diameter);
    await prefs.setDouble(_keyLength, length);
  }

  Future<String?> getCurrentSpecies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpecies);
  }

  Future<void> saveCurrentSpecies(String? species) async {
    final prefs = await SharedPreferences.getInstance();
    if (species == null) {
      await prefs.remove(_keySpecies);
    } else {
      await prefs.setString(_keySpecies, species);
    }
  }
}

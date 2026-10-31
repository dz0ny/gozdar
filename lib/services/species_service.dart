import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage tree species list
class SpeciesService {
  static const String _keySpecies = 'species_list';

  // Default species (Slovenian tree types)
  static const List<String> _defaultSpecies = [
    'Smreka',
    'Bukev',
    'Jelka',
  ];

  /// Get the list of available species
  Future<List<String>> getSpecies() async {
    final prefs = await SharedPreferences.getInstance();
    final species = prefs.getStringList(_keySpecies);

    // Defaults only on first run (nothing saved yet). An empty saved list
    // means the user removed every species and must stay empty.
    if (species == null) {
      return List.from(_defaultSpecies);
    }

    return species;
  }

  /// Save the list of species
  Future<void> saveSpecies(List<String> species) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySpecies, species);
  }

  /// Add a new species to the list. Returns false when it is empty or already
  /// exists (compared case-insensitively).
  Future<bool> addSpecies(String species) async {
    final name = species.trim();
    if (name.isEmpty) return false;

    final currentSpecies = await getSpecies();
    final lower = name.toLowerCase();
    if (currentSpecies.any((s) => s.toLowerCase() == lower)) return false;
    currentSpecies.add(name);
    await saveSpecies(currentSpecies);
    return true;
  }

  /// Remove a species from the list
  Future<void> removeSpecies(String species) async {
    final currentSpecies = await getSpecies();
    currentSpecies.remove(species);
    await saveSpecies(currentSpecies);
  }

  /// Reset to default species
  Future<void> resetToDefaults() async {
    await saveSpecies(List.from(_defaultSpecies));
  }
}

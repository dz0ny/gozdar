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

    if (species == null || species.isEmpty) {
      // Return default species if none saved
      return List.from(_defaultSpecies);
    }

    return species;
  }

  /// Save the list of species
  Future<void> saveSpecies(List<String> species) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySpecies, species);
  }

  /// Add a new species to the list
  Future<void> addSpecies(String species) async {
    if (species.trim().isEmpty) return;

    final currentSpecies = await getSpecies();
    if (!currentSpecies.contains(species.trim())) {
      currentSpecies.add(species.trim());
      await saveSpecies(currentSpecies);
    }
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

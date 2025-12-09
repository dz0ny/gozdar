import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing parcel search history (KO numbers and parcel numbers)
/// Stores recent searches for autocomplete suggestions
class ParcelSearchHistoryService {
  static final ParcelSearchHistoryService _instance =
      ParcelSearchHistoryService._internal();
  factory ParcelSearchHistoryService() => _instance;
  ParcelSearchHistoryService._internal();

  static const String _koHistoryKey = 'parcel_search_ko_history';
  static const String _parcelHistoryKey = 'parcel_search_parcel_history';
  static const int _maxHistoryItems = 10;

  /// Get recent KO numbers
  Future<List<String>> getKoHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_koHistoryKey) ?? [];
  }

  /// Get recent parcel numbers
  Future<List<String>> getParcelHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_parcelHistoryKey) ?? [];
  }

  /// Add KO number to history (most recent first)
  Future<void> addKoToHistory(String koNumber) async {
    if (koNumber.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final history = await getKoHistory();

    // Remove if already exists (to move to front)
    history.remove(koNumber);

    // Add to front
    history.insert(0, koNumber);

    // Keep only max items
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    await prefs.setStringList(_koHistoryKey, history);
  }

  /// Add parcel number to history (most recent first)
  Future<void> addParcelToHistory(String parcelNumber) async {
    if (parcelNumber.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final history = await getParcelHistory();

    // Remove if already exists (to move to front)
    history.remove(parcelNumber);

    // Add to front
    history.insert(0, parcelNumber);

    // Keep only max items
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    await prefs.setStringList(_parcelHistoryKey, history);
  }

  /// Clear all search history
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_koHistoryKey);
    await prefs.remove(_parcelHistoryKey);
  }
}

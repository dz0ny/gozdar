import 'package:shared_preferences/shared_preferences.dart';

/// Developer toggles for the two independent caches:
/// - HTTP cache: govt API responses (`HttpCacheService`, drift `httpCache`).
/// - Tile cache: map tiles (flutter_map's built-in caching provider).
///
/// They share no storage; these flags gate each one separately at runtime.
class CacheSettings {
  CacheSettings._();
  static final CacheSettings instance = CacheSettings._();

  static const _httpKey = 'cache_http_enabled';
  static const _tileKey = 'cache_tile_enabled';

  /// Bumped when the defaults should win over whatever a previous build left
  /// in prefs (the toggles used to be easy to flip off from the dev panel).
  static const _resetKey = 'cache_defaults_version';
  static const _resetVersion = 1;

  bool _httpEnabled = true;
  bool _tileEnabled = true;

  bool get httpEnabled => _httpEnabled;
  bool get tileEnabled => _tileEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(_resetKey) ?? 0) < _resetVersion) {
      // One-time: re-enable both caches on every install.
      await prefs.remove(_httpKey);
      await prefs.remove(_tileKey);
      await prefs.setInt(_resetKey, _resetVersion);
    }
    _httpEnabled = prefs.getBool(_httpKey) ?? true;
    _tileEnabled = prefs.getBool(_tileKey) ?? true;
  }

  Future<void> setHttpEnabled(bool value) async {
    _httpEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_httpKey, value);
  }

  Future<void> setTileEnabled(bool value) async {
    _tileEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tileKey, value);
  }
}

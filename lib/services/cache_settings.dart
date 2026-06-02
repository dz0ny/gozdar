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

  bool _httpEnabled = true;
  bool _tileEnabled = true;

  bool get httpEnabled => _httpEnabled;
  bool get tileEnabled => _tileEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
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

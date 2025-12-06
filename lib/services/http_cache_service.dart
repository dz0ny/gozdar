import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

/// HTTP cache service for prostor.zgs.gov.si requests
/// Caches successful (200) responses for up to 1 year
class HttpCacheService {
  static final HttpCacheService _instance = HttpCacheService._internal();
  static Database? _database;

  // Cache TTL: 1 year in milliseconds
  static const int _cacheTtlMs = 365 * 24 * 60 * 60 * 1000;

  // Domain to cache
  static const String _cachedDomain = 'prostor.zgs.gov.si';

  factory HttpCacheService() {
    return _instance;
  }

  HttpCacheService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'http_cache.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE http_cache (
        url_hash TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        response_body TEXT NOT NULL,
        status_code INTEGER NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Index for cleanup queries
    await db.execute('''
      CREATE INDEX idx_cached_at ON http_cache(cached_at)
    ''');
  }

  /// Generate a hash for the URL to use as cache key
  String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Check if URL should be cached
  bool _shouldCache(Uri uri) {
    return uri.host == _cachedDomain || uri.host.endsWith('.$_cachedDomain');
  }

  /// Get cached response if available and not expired
  Future<http.Response?> getCached(Uri uri) async {
    if (!_shouldCache(uri)) return null;

    try {
      final db = await database;
      final urlHash = _hashUrl(uri.toString());
      final now = DateTime.now().millisecondsSinceEpoch;

      final results = await db.query(
        'http_cache',
        where: 'url_hash = ? AND cached_at > ?',
        whereArgs: [urlHash, now - _cacheTtlMs],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final row = results.first;
      final statusCode = row['status_code'] as int;
      final body = row['response_body'] as String;

      // Return cached response
      return http.Response(body, statusCode);
    } catch (e, stackTrace) {
      // On any cache error, log and return null to fetch fresh
      debugPrint('HttpCacheService.getCached error: $e\n$stackTrace');
      return null;
    }
  }

  /// Store response in cache (only for 200 responses)
  Future<void> cacheResponse(Uri uri, http.Response response) async {
    if (!_shouldCache(uri)) return;
    if (response.statusCode != 200) return;

    try {
      final db = await database;
      final urlHash = _hashUrl(uri.toString());
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert('http_cache', {
        'url_hash': urlHash,
        'url': uri.toString(),
        'response_body': response.body,
        'status_code': response.statusCode,
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, stackTrace) {
      // Caching is best-effort, but log errors for debugging
      debugPrint('HttpCacheService.cacheResponse error: $e\n$stackTrace');
    }
  }

  /// Perform HTTP GET with caching
  Future<http.Response> get(Uri uri, {Duration? timeout}) async {
    // Try to get from cache first
    final cached = await getCached(uri);
    if (cached != null) {
      return cached;
    }

    // Fetch from network
    final response = timeout != null
        ? await http.get(uri).timeout(timeout)
        : await http.get(uri);

    // Cache successful responses
    if (response.statusCode == 200) {
      await cacheResponse(uri, response);
    }

    return response;
  }

  /// Clear all expired cache entries
  Future<int> clearExpired() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cutoff = now - _cacheTtlMs;

      return await db.delete(
        'http_cache',
        where: 'cached_at < ?',
        whereArgs: [cutoff],
      );
    } catch (e, stackTrace) {
      debugPrint('HttpCacheService.clearExpired error: $e\n$stackTrace');
      return 0;
    }
  }

  /// Clear all cache entries
  Future<int> clearAll() async {
    try {
      final db = await database;
      return await db.delete('http_cache');
    } catch (e, stackTrace) {
      debugPrint('HttpCacheService.clearAll error: $e\n$stackTrace');
      return 0;
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cutoff = now - _cacheTtlMs;

      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as total, SUM(LENGTH(response_body)) as size FROM http_cache WHERE cached_at > ?',
        [cutoff],
      );

      final total = countResult.first['total'] as int? ?? 0;
      final size = countResult.first['size'] as int? ?? 0;

      return {
        'entries': total,
        'sizeBytes': size,
        'sizeMB': (size / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e, stackTrace) {
      debugPrint('HttpCacheService.getStats error: $e\n$stackTrace');
      return {'entries': 0, 'sizeBytes': 0, 'sizeMB': '0.00'};
    }
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

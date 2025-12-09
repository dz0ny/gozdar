import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../objectbox.g.dart';
import '../models/http_cache_entry.dart';
import 'database_service.dart';

/// HTTP cache service for prostor.zgs.gov.si and Cloudflare Worker requests
/// Caches successful (200) responses for up to 1 year
class HttpCacheService {
  static final HttpCacheService _instance = HttpCacheService._internal();

  // Cache TTL: 1 year
  static const Duration _cacheTtl = Duration(days: 365);

  // Domains to cache
  static const String _cachedDomain = 'prostor.zgs.gov.si';
  static const String _workerDomain = 'gozdar-proxy.dz0ny.workers.dev';

  factory HttpCacheService() {
    return _instance;
  }

  HttpCacheService._internal();

  Box<HttpCacheEntry> get _cacheBox => DatabaseService().store.box<HttpCacheEntry>();

  /// Generate a hash for the URL to use as cache key
  String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Check if URL should be cached
  bool _shouldCache(Uri uri) {
    return uri.host == _cachedDomain ||
           uri.host.endsWith('.$_cachedDomain') ||
           uri.host == _workerDomain;
  }

  /// Get cached response if available and not expired
  Future<http.Response?> getCached(Uri uri) async {
    if (!_shouldCache(uri)) return null;

    try {
      final urlHash = _hashUrl(uri.toString());
      final cutoff = DateTime.now().subtract(_cacheTtl);

      final query = _cacheBox.query(
        HttpCacheEntry_.urlHash.equals(urlHash) &
            HttpCacheEntry_.cachedAt.greaterThan(cutoff.millisecondsSinceEpoch),
      ).build();

      final entry = query.findFirst();
      query.close();

      if (entry == null) return null;

      // Return cached response
      return http.Response(entry.responseBody, entry.statusCode);
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
      final urlHash = _hashUrl(uri.toString());

      // Remove existing entry with same hash if exists
      final existingQuery = _cacheBox.query(HttpCacheEntry_.urlHash.equals(urlHash)).build();
      existingQuery.remove();
      existingQuery.close();

      // Insert new entry
      final entry = HttpCacheEntry(
        urlHash: urlHash,
        url: uri.toString(),
        responseBody: response.body,
        statusCode: response.statusCode,
      );
      _cacheBox.put(entry);
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
      final cutoff = DateTime.now().subtract(_cacheTtl);
      final query = _cacheBox
          .query(HttpCacheEntry_.cachedAt.lessThan(cutoff.millisecondsSinceEpoch))
          .build();
      final count = query.remove();
      query.close();
      return count;
    } catch (e, stackTrace) {
      debugPrint('HttpCacheService.clearExpired error: $e\n$stackTrace');
      return 0;
    }
  }

  /// Clear all cache entries
  Future<int> clearAll() async {
    try {
      final count = _cacheBox.count();
      _cacheBox.removeAll();
      return count;
    } catch (e, stackTrace) {
      debugPrint('HttpCacheService.clearAll error: $e\n$stackTrace');
      return 0;
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      final cutoff = DateTime.now().subtract(_cacheTtl);
      final query = _cacheBox
          .query(HttpCacheEntry_.cachedAt.greaterThan(cutoff.millisecondsSinceEpoch))
          .build();
      final entries = query.find();
      query.close();

      final total = entries.length;
      final size = entries.fold<int>(0, (sum, e) => sum + e.responseBody.length);

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
}

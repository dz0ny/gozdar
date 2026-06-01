import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../db/app_database.dart';
import 'database_service.dart';

class HttpCacheService {
  static final HttpCacheService _instance = HttpCacheService._internal();

  static const Duration _cacheTtl = Duration(days: 365);
  static const String _cachedDomain = 'prostor.zgs.gov.si';
  static const String _workerDomain = 'gozdar-proxy.dz0ny.workers.dev';

  factory HttpCacheService() => _instance;
  HttpCacheService._internal();

  AppDatabase get _db => DatabaseService().db;

  String _hashUrl(String url) => md5.convert(utf8.encode(url)).toString();

  bool _shouldCache(Uri uri) =>
      uri.host == _cachedDomain ||
      uri.host.endsWith('.$_cachedDomain') ||
      uri.host == _workerDomain;

  Future<http.Response?> getCached(Uri uri) async {
    if (!_shouldCache(uri)) return null;
    try {
      final urlHash = _hashUrl(uri.toString());
      final cutoff = DateTime.now().subtract(_cacheTtl);
      final row = await (_db.select(_db.httpCache)
            ..where((t) => t.urlHash.equals(urlHash) & t.cachedAt.isBiggerThanValue(cutoff)))
          .getSingleOrNull();
      if (row == null) return null;
      return http.Response(row.responseBody, row.statusCode);
    } catch (e, st) {
      debugPrint('HttpCacheService.getCached error: $e\n$st');
      return null;
    }
  }

  Future<void> cacheResponse(Uri uri, http.Response response) async {
    if (!_shouldCache(uri) || response.statusCode != 200) return;
    try {
      final urlHash = _hashUrl(uri.toString());
      await (_db.delete(_db.httpCache)..where((t) => t.urlHash.equals(urlHash))).go();
      await _db.into(_db.httpCache).insert(HttpCacheCompanion.insert(
            urlHash: urlHash,
            url: uri.toString(),
            responseBody: response.body,
            statusCode: response.statusCode,
            cachedAt: DateTime.now(),
          ));
    } catch (e, st) {
      debugPrint('HttpCacheService.cacheResponse error: $e\n$st');
    }
  }

  Future<http.Response> get(Uri uri, {Duration? timeout}) async {
    final cached = await getCached(uri);
    if (cached != null) return cached;
    try {
      final response = timeout != null
          ? await http.get(uri).timeout(timeout)
          : await http.get(uri);
      if (response.statusCode == 200) {
        await cacheResponse(uri, response);
      } else {
        debugPrint('HTTP ${response.statusCode} for $uri');
      }
      return response;
    } catch (e) {
      debugPrint('HTTP request failed for $uri: $e');
      rethrow;
    }
  }

  Future<int> clearExpired() async {
    try {
      final cutoff = DateTime.now().subtract(_cacheTtl);
      return (_db.delete(_db.httpCache)..where((t) => t.cachedAt.isSmallerThanValue(cutoff))).go();
    } catch (e, st) {
      debugPrint('HttpCacheService.clearExpired error: $e\n$st');
      return 0;
    }
  }

  Future<int> clearAll() async {
    try {
      final count = await _db.httpCache.count().getSingle();
      await _db.delete(_db.httpCache).go();
      return count;
    } catch (e, st) {
      debugPrint('HttpCacheService.clearAll error: $e\n$st');
      return 0;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final cutoff = DateTime.now().subtract(_cacheTtl);
      final rows = await (_db.select(_db.httpCache)
            ..where((t) => t.cachedAt.isBiggerThanValue(cutoff)))
          .get();
      final total = rows.length;
      final size = rows.fold<int>(0, (sum, r) => sum + r.responseBody.length);
      return {'entries': total, 'sizeBytes': size, 'sizeMB': (size / (1024 * 1024)).toStringAsFixed(2)};
    } catch (e, st) {
      debugPrint('HttpCacheService.getStats error: $e\n$st');
      return {'entries': 0, 'sizeBytes': 0, 'sizeMB': '0.00'};
    }
  }
}

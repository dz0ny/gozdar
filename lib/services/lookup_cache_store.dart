import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import 'database_service.dart';

/// One cached answer: its key and the JSON it was stored as.
typedef LookupCacheRow = ({String key, Map<String, dynamic> payload});

/// Answers of one online lookup kept in the `lookup_cache` table, one row
/// per answer. Rows are stored under `<source>.v<version>`; raising
/// [version] drops the rows of every earlier version on the next run, as it
/// does [legacyFiles], the JSON files the answers were kept in before.
///
/// Without an open database (widget tests) nothing is read or kept.
class LookupCacheStore {
  LookupCacheStore(
    this.source, {
    required this.version,
    this.legacyFiles = const [],
  });

  final String source;
  final int version;
  final List<String> legacyFiles;

  String get kind => '$source.v$version';

  bool get _isOpen => DatabaseService().isInitialized;
  AppDatabase get _db => DatabaseService().db;

  Future<void>? _cleanup;

  /// The answer stored under [key], or null.
  Future<Map<String, dynamic>?> read(String key) async {
    if (!_isOpen) return null;
    try {
      await _dropOld();
      final row =
          await (_db.select(_db.lookupCache)
                ..where((t) => t.kind.equals(kind) & t.cacheKey.equals(key)))
              .getSingleOrNull();
      return row == null ? null : _decode(row.payload);
    } catch (e) {
      debugPrint('LookupCacheStore($kind) read failed: $e');
      return null;
    }
  }

  /// Stores [payload] under [key], replacing what was there. [search] is the
  /// folded text [search] matches against.
  Future<void> write(
    String key,
    Map<String, dynamic> payload, {
    String search = '',
  }) async {
    if (!_isOpen) return;
    try {
      await _db
          .into(_db.lookupCache)
          .insertOnConflictUpdate(
            LookupCacheCompanion.insert(
              kind: kind,
              cacheKey: key,
              payload: jsonEncode(payload),
              search: Value(search),
              cachedAt: DateTime.now(),
            ),
          );
    } catch (e) {
      debugPrint('LookupCacheStore($kind) write failed: $e');
    }
  }

  /// Every stored answer, oldest first.
  Future<List<LookupCacheRow>> all() async {
    if (!_isOpen) return const [];
    try {
      await _dropOld();
      final rows =
          await (_db.select(_db.lookupCache)
                ..where((t) => t.kind.equals(kind))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.cachedAt),
                  (t) => OrderingTerm.asc(t.rowId),
                ]))
              .get();
      return _rows(rows);
    } catch (e) {
      debugPrint('LookupCacheStore($kind) list failed: $e');
      return const [];
    }
  }

  /// Answers whose search text contains every one of [terms] (already
  /// folded), at most [limit]. [keyPrefix] restricts to keys starting with
  /// it.
  Future<List<LookupCacheRow>> search(
    List<String> terms, {
    String? keyPrefix,
    int limit = 15,
  }) async {
    if (!_isOpen) return const [];
    try {
      await _dropOld();
      final rows =
          await (_db.select(_db.lookupCache)
                ..where((t) {
                  var match = t.kind.equals(kind);
                  // instr, not LIKE: a typed % or _ is not a wildcard.
                  for (final term in terms) {
                    match = match & _has(t.search, term);
                  }
                  if (keyPrefix != null) {
                    match =
                        match &
                        FunctionCallExpression<String>('substr', [
                          t.cacheKey,
                          const Constant(1),
                          Constant(keyPrefix.length),
                        ]).equals(keyPrefix);
                  }
                  return match;
                })
                ..limit(limit))
              .get();
      return _rows(rows);
    } catch (e) {
      debugPrint('LookupCacheStore($kind) search failed: $e');
      return const [];
    }
  }

  /// Deletes all but the [count] newest answers.
  Future<void> keepNewest(int count) async {
    if (!_isOpen) return;
    try {
      await _db.customUpdate(
        'DELETE FROM lookup_cache WHERE kind = ?1 AND cache_key NOT IN '
        '(SELECT cache_key FROM lookup_cache WHERE kind = ?1 '
        'ORDER BY cached_at DESC, rowid DESC LIMIT ?2)',
        variables: [Variable.withString(kind), Variable.withInt(count)],
        updates: {_db.lookupCache},
        updateKind: UpdateKind.delete,
      );
    } catch (e) {
      debugPrint('LookupCacheStore($kind) trim failed: $e');
    }
  }

  static Expression<bool> _has(Expression<String> column, String term) =>
      FunctionCallExpression<int>('instr', [
        column,
        Variable.withString(term),
      ]).isBiggerThanValue(0);

  static Map<String, dynamic>? _decode(String payload) {
    final value = jsonDecode(payload);
    return value is Map<String, dynamic> ? value : null;
  }

  static List<LookupCacheRow> _rows(List<DbLookupCacheEntry> rows) => [
    for (final r in rows)
      if (_decode(r.payload) case final payload?)
        (key: r.cacheKey, payload: payload),
  ];

  /// Rows of earlier versions and the legacy files, dropped once per run.
  Future<void> _dropOld() => _cleanup ??= () async {
    try {
      await (_db.delete(_db.lookupCache)..where(
            (t) => t.kind.like('$source.v%') & t.kind.equals(kind).not(),
          ))
          .go();
    } catch (e) {
      debugPrint('LookupCacheStore($kind) old rows drop failed: $e');
    }
    if (legacyFiles.isEmpty) return;
    try {
      final dir = await getApplicationSupportDirectory();
      for (final name in legacyFiles) {
        final file = File('${dir.path}/$name');
        if (file.existsSync()) await file.delete();
      }
    } catch (e) {
      debugPrint('LookupCacheStore($kind) legacy file delete failed: $e');
    }
  }();

  /// Forgets that the old rows were dropped, for tests that swap databases.
  @visibleForTesting
  void debugReset() => _cleanup = null;
}

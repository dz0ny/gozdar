import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'aes_file_decryptor.dart';
import 'parcel_lookup_service.dart';
import 'public_parcel_settings.dart';
import 'remote_asset.dart';

/// Thrown when an owners-database download is cancelled by the caller.
class OwnerDownloadCancelled implements Exception {
  const OwnerDownloadCancelled();
}

/// Owner(s) + address looked up for a single cadastral parcel.
class OwnerInfo {
  /// Distinct owner names (co-owners), already de-duplicated.
  final List<String> owners;

  /// First non-empty owner address found for the parcel, if any.
  final String? address;

  /// Cadastral municipality (katastrska občina) name, e.g. "BABNO POLJE".
  final String? koName;

  /// Administrative municipality (občina), often null in the source data.
  final String? municipality;

  const OwnerInfo({
    required this.owners,
    this.address,
    this.koName,
    this.municipality,
  });

  /// Owner names joined for display, e.g. "NOVAK JANEZ • KOVAC ANA".
  String get displayOwners => owners.join(' • ');
}

/// Result of importing an owners database file.
class OwnerImportResult {
  final int rows;
  const OwnerImportResult(this.rows);
}

/// Read-only lookup of cadastral parcel owners from an imported `owners.sqlite`
/// (built by `tool/build_owners_db.sh` from the GURS extract).
///
/// The database is a separate, read-only SQLite file living next to the drift
/// database in the application-support directory. It is intentionally kept out
/// of the drift schema so migrations never touch it. Hidden import lives in the
/// About screen.
class OwnerLookupService {
  OwnerLookupService._();
  static final OwnerLookupService instance = OwnerLookupService._();
  factory OwnerLookupService() => instance;

  static const _fileName = 'owners.sqlite';

  // Redistributable public-owners DB (legal-entity owners + managers, built
  // from the GURS KN open data; CC-BY). Hosted on R2 and downloaded on first
  // use (like the kataster) rather than bundled, to keep the app small.
  static const _publicFileName = 'public_owners.sqlite';
  static String get _publicUrl =>
      '${ParcelLookupService.r2BaseUrl}/$_publicFileName';

  Database? _db;
  String? _path;

  /// Whether the open database has the trigram search tables built by
  /// [_buildSearchIndex]. Until then searches fall back to a full scan.
  bool _hasSearchIndex = false;
  Future<void>? _indexBuild;
  int _rowCount = 0;
  String? _source; // 'imported' | 'downloaded'

  Database? _publicDb;
  int _publicRowCount = 0;
  String? _publicBuilt;

  /// Number of rows in the embedded public-owners DB (0 when unavailable).
  int get publicRowCount => _publicRowCount;

  /// Build timestamp (`meta.built`, ISO-8601) of the open public-owners DB, or
  /// null when it is not open or carries none.
  String? get publicBuilt => _publicBuilt;

  /// How the loaded database was obtained: `'imported'` (file picker) or
  /// `'downloaded'` (R2), or null when unavailable. Tracked via a `.src` marker.
  String? get source => _source;

  /// Whether the open database carries the per-parcel bounding-box columns
  /// (`min_lon`/`max_lon`/`min_lat`/`max_lat`) needed for offline reverse
  /// lookup. Detected once at [_open]; old imported databases may lack them.
  bool _hasGeometry = false;

  /// Cache of cadastral municipality (KO) names keyed by [sifko]. Null values
  /// are cached too (negative lookups). Cleared when the database changes.
  final Map<int, String?> _koNameCache = {};

  /// Whether owner lookups can be answered — either the embedded public DB or
  /// an imported/downloaded private DB is open.
  bool get isAvailable => _db != null || _publicDb != null;

  /// Number of owner rows in the imported database (0 when unavailable).
  int get rowCount => _rowCount;

  /// Whether the open database has per-parcel bounding boxes (and can therefore
  /// answer offline reverse lookups via [findOwnersAt]). False when no database
  /// is imported or when an older database without bbox columns was imported.
  bool get hasGeometry => _hasGeometry;

  Future<String> _targetPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}$_fileName';
  }

  /// Size of the imported database file in bytes, or null when unavailable.
  Future<int?> fileSizeBytes() async {
    final path = _path ?? await _targetPath();
    final file = File(path);
    return await file.exists() ? file.length() : null;
  }

  /// Opens [path] directly, for tests and screenshots.
  @visibleForTesting
  void openForTesting(String path) => _open(path);

  /// Builds the search index for the database opened with [openForTesting].
  @visibleForTesting
  Future<void> buildSearchIndexForTesting() async {
    _scheduleSearchIndex();
    await _indexBuild;
  }

  bool get hasSearchIndex => _hasSearchIndex;

  /// Open the database if it exists. Safe to call on every app start.
  Future<void> init() async {
    try {
      _path = await _targetPath();
      if (!File(_path!).existsSync()) return;
      _open(_path!);
      _scheduleSearchIndex();
    } catch (e) {
      debugPrint('OwnerLookupService.init failed: $e');
      _close();
    }
  }

  /// Open the public-owners database if present; otherwise download it from R2
  /// in the background (first use) and open it when ready. Returns quickly so
  /// app start is never blocked by the large download.
  Future<void> initPublic() async {
    try {
      final path = await RemoteAsset.localPath(_publicFileName);
      if (File(path).existsSync()) {
        _openPublic(path);
        return;
      }
      unawaited(_downloadPublic());
    } catch (e) {
      debugPrint('OwnerLookupService.initPublic failed: $e');
      _publicDb?.close();
      _publicDb = null;
    }
  }

  Future<void> _downloadPublic() async {
    final path = await RemoteAsset.ensure(_publicUrl, _publicFileName);
    if (path == null) return;
    try {
      _openPublic(path);
    } catch (e) {
      debugPrint('OwnerLookupService._downloadPublic open failed: $e');
    }
  }

  /// Re-download the public-owners DB from R2 and swap it in. The current DB
  /// keeps serving lookups until the new file has fully arrived. Returns false
  /// when the download failed (the old DB stays open).
  Future<bool> refreshPublic({
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final path = await RemoteAsset.ensure(
      _publicUrl,
      _publicFileName,
      onProgress: onProgress,
      refresh: true,
      beforeSwap: () async => _closePublic(),
      isCancelled: isCancelled,
    );
    if (path == null) {
      // Download failed before the swap (DB still open) or the swap itself
      // failed after we closed it — in the latter case reopen the old copy.
      if (_publicDb == null) await initPublic();
      return false;
    }
    try {
      _openPublic(path);
      return true;
    } catch (e) {
      debugPrint('OwnerLookupService.refreshPublic open failed: $e');
      return false;
    }
  }

  void _closePublic() {
    _publicDb?.close();
    _publicDb = null;
    _publicRowCount = 0;
    _publicBuilt = null;
  }

  void _openPublic(String path) {
    final db = sqlite3.open(path);
    final ok = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('owners','names')",
    );
    if (ok.length < 2) {
      db.close();
      throw const FormatException('Neveljavna javna baza lastnikov.');
    }
    try {
      final meta = db.select("SELECT v FROM meta WHERE k='rows'");
      _publicRowCount =
          meta.isEmpty ? 0 : (int.tryParse(meta.first['v'].toString()) ?? 0);
    } catch (_) {
      _publicRowCount = 0;
    }
    try {
      final built = db.select("SELECT v FROM meta WHERE k='built'");
      _publicBuilt = built.isEmpty ? null : built.first['v']?.toString();
    } catch (_) {
      _publicBuilt = null;
    }
    _publicDb?.close();
    _publicDb = db;
  }

  void _open(String path) {
    // Open read-write (the file lives in our writable app-support dir). A
    // read-only open fails with SQLITE_CANTOPEN(14) for WAL-mode databases,
    // because SQLite cannot create the required -wal/-shm sidecar files.
    final db = sqlite3.open(path);
    // Validate it is actually an owners database.
    final hasTable = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='owners'",
    );
    if (hasTable.isEmpty) {
      db.close();
      throw const FormatException('Datoteka ni veljavna baza lastnikov.');
    }
    // The search index is built on a second connection; wait for its
    // commit instead of failing lookups with SQLITE_BUSY.
    db.execute('PRAGMA busy_timeout = 5000');
    _rowCount = _readRowCount(db);
    _hasGeometry = _detectGeometry(db);
    _hasSearchIndex = _detectSearchIndex(db);
    _source = _readSource(path);
    _db = db;
    _path = path;
  }

  static bool _detectSearchIndex(Database db) => db.select(
    "SELECT name FROM sqlite_master WHERE name IN "
    "('owner_name_search', 'owner_address_search')",
  ).length == 2;

  /// Builds the search index in a background isolate if the open database
  /// lacks it. Runs once per database; searches use the slower full scan
  /// until it is ready.
  void _scheduleSearchIndex() {
    final path = _path;
    if (_db == null || path == null || _hasSearchIndex || _indexBuild != null) {
      return;
    }
    _indexBuild = _buildSearchIndexInBackground(path)
        .then((_) {
          if (_path == path && _db != null) _hasSearchIndex = true;
        })
        .catchError((Object e) {
          debugPrint('OwnerLookupService search index build failed: $e');
        })
        .whenComplete(() => _indexBuild = null);
  }

  // Static so the isolate closures capture only plain values, never this
  // service and its open (unsendable) database connection.
  static Future<void> _buildSearchIndexInBackground(String path) =>
      Isolate.run(() => _buildSearchIndex(path));

  static Future<OwnerSearchResult> _searchInBackground(
    String path, {
    required bool indexed,
    String? name,
    String? address,
    required int limit,
  }) => Isolate.run(() {
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA busy_timeout = 5000');
      return _search(
        db,
        indexed: indexed,
        name: name,
        address: address,
        limit: limit,
      );
    } finally {
      db.close();
    }
  });

  /// Adds trigram full-text tables over the distinct owner names and
  /// addresses (folded like [foldForSearch]) plus B-tree indexes to fetch
  /// their parcels. A substring search then touches ~100k short terms
  /// instead of scanning every owner row. Built in one transaction, so an
  /// interrupted build leaves nothing behind and is retried on next open.
  static void _buildSearchIndex(String path) {
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA busy_timeout = 10000');
      if (_detectSearchIndex(db)) return;
      db.execute('BEGIN IMMEDIATE');
      try {
        for (final (table, column) in [
          ('owner_name_search', 'lastnik'),
          ('owner_address_search', 'naslov'),
        ]) {
          db.execute(
            'CREATE INDEX IF NOT EXISTS idx_owners_$column ON owners($column)',
          );
          db.execute(
            'CREATE VIRTUAL TABLE $table '
            "USING fts5(term UNINDEXED, term_f, tokenize='trigram')",
          );
          db.execute(
            'INSERT INTO $table(term, term_f) '
            'SELECT $column, ${_foldSql('UPPER($column)')} FROM '
            '(SELECT DISTINCT $column FROM owners '
            "WHERE $column IS NOT NULL AND $column <> '')",
          );
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.close();
    }
  }

  String? _readSource(String path) {
    try {
      final f = File('$path.src');
      if (f.existsSync()) {
        final v = f.readAsStringSync().trim();
        return v.isNotEmpty ? v : null;
      }
    } catch (_) {}
    return null;
  }

  void _writeSource(String path, String src) {
    try {
      File('$path.src').writeAsStringSync(src);
      _source = src;
    } catch (e) {
      debugPrint('OwnerLookupService._writeSource failed: $e');
    }
  }

  /// Detect whether the database carries per-parcel bounding-box columns. Be
  /// defensive: an old database simply lacks them and the feature stays off.
  bool _detectGeometry(Database db) {
    try {
      final cols = db.select('PRAGMA table_info(owners)');
      return cols.any((c) => c['name'] == 'min_lat');
    } catch (e) {
      debugPrint('OwnerLookupService._detectGeometry failed: $e');
      return false;
    }
  }

  int _readRowCount(Database db) {
    try {
      final meta = db.select("SELECT v FROM meta WHERE k='rows'");
      if (meta.isNotEmpty) {
        return int.tryParse(meta.first['v'].toString()) ?? 0;
      }
    } catch (_) {
      // meta table missing — fall back to a COUNT.
    }
    final c = db.select('SELECT COUNT(*) AS n FROM owners');
    return c.isEmpty ? 0 : (c.first['n'] as int);
  }

  void _close() {
    _db?.close();
    _db = null;
    _hasSearchIndex = false;
    _rowCount = 0;
    _hasGeometry = false;
    _source = null;
    _koNameCache.clear();
  }

  /// Import (copy) a picked `.sqlite` file into the app and open it. Replaces any
  /// previously imported database. Throws [FormatException] with a Slovenian
  /// message when the file is not a valid owners database.
  ///
  /// The file is copied into our writable app-support dir *before* it is opened.
  /// The picker hands back a path in a temporary / security-scoped location that
  /// the native SQLite library often cannot open directly (SQLITE_CANTOPEN), and
  /// WAL-mode databases need a writable directory for their -wal/-shm sidecars.
  Future<OwnerImportResult> importFromFile(String sourcePath) async {
    final target = await _targetPath();

    _close();
    await _deleteDbFiles(target);
    await File(sourcePath).copy(target);
    _path = target;
    try {
      // Opens read-write and validates that the 'owners' table exists.
      _open(target);
      _writeSource(target, 'imported');
      _scheduleSearchIndex();
    } on FormatException {
      await _deleteDbFiles(target);
      _path = null;
      throw const FormatException('Izbrana datoteka ni baza lastnikov.');
    } catch (e) {
      await _deleteDbFiles(target);
      _path = null;
      rethrow;
    }
    return OwnerImportResult(_rowCount);
  }

  /// Stream-download the owners database from [url] into the app and open it.
  /// When [password] is given the download is treated as an AES-256 encrypted
  /// file (see [AesFileDecryptor]) and decrypted on the fly. Reports progress
  /// via [onProgress]; throw via [isCancelled] to abort. Downloads to a `.part`
  /// file and only replaces the live database on success, so a failed/cancelled
  /// download never corrupts an existing one.
  Future<OwnerImportResult> downloadAndOpen(
    String url, {
    String? password,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final target = await _targetPath();
    final part = File('$target.part');
    if (await part.exists()) await part.delete();

    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) {
        throw FormatException('Prenos ni uspel (HTTP ${response.statusCode}).');
      }
      final total = response.contentLength;
      final sink = part.openWrite();
      try {
        if (password != null && password.isNotEmpty) {
          await AesFileDecryptor.decrypt(
            input: response.stream,
            out: sink,
            password: password,
            onBytes: (b) => onProgress?.call(b, total),
            isCancelled: isCancelled,
          );
        } else {
          var received = 0;
          await for (final chunk in response.stream) {
            if (isCancelled?.call() ?? false) {
              throw const OwnerDownloadCancelled();
            }
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(received, total);
          }
        }
      } on AesCancelled {
        throw const OwnerDownloadCancelled();
      } on AesDecryptException catch (e) {
        throw FormatException(e.message);
      } finally {
        await sink.close();
      }

      _close();
      await _deleteDbFiles(target);
      await part.rename(target);
      _path = target;
      try {
        _open(target);
        _writeSource(target, 'downloaded');
        _scheduleSearchIndex();
      } on FormatException {
        await _deleteDbFiles(target);
        _path = null;
        throw const FormatException('Prenesena datoteka ni baza lastnikov.');
      }
      return OwnerImportResult(_rowCount);
    } finally {
      client.close();
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
    }
  }

  /// Delete the imported database.
  Future<void> remove() async {
    _close();
    final path = _path ?? await _targetPath();
    await _deleteDbFiles(path);
  }

  /// Delete the database file together with its WAL/SHM/journal sidecars.
  Future<void> _deleteDbFiles(String path) async {
    for (final suffix in ['', '-wal', '-shm', '-journal', '.src']) {
      final file = File('$path$suffix');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('OwnerLookupService._deleteDbFiles($suffix) failed: $e');
        }
      }
    }
  }

  /// Repair the known string-encoding corruption in GURS owner names. The
  /// source data mangled Slovenian/Croatian special letters into a '?' plus a
  /// stray character. The dominant case ("?ć", ~97% of corrupted names —
  /// the -IĆ surnames) maps confidently to Ć; "?î" maps to Č
  /// (e.g. SREČKO). Any remaining stray '?' before a non-ASCII letter is
  /// dropped so names read cleanly. The '?' is lossy, so rare cases stay
  /// approximate.
  static final _strayMarker = RegExp('\\?(?=[^\\u0000-\\u007F])');
  static String? _repairEncoding(String? s) {
    if (s == null || !s.contains('?')) return s;
    return s
        .replaceAll('?\u0107', '\u0106') // ?ć -> Ć
        .replaceAll('?\u00EE', '\u010C') // ?î -> Č
        .replaceAll('?á', 'Š') // ?a-acute -> S-caron
        .replaceAll('?Ż', 'Ž') // ?Z-dot -> Z-caron
        .replaceAll('?É', 'Đ') // ?E-acute -> D-stroke
        .replaceAll('?ä', 'Ä') // ?a-uml -> A-uml
        .replaceAll('?ë', 'É') // ?e-uml -> E-acute
        .replaceAll('?ö', 'Ô') // ?o-uml -> O-circumflex
        .replaceAll('?ü', 'Ü') // ?u-uml -> U-uml
        .replaceAll('?ľ', 'Ü') // ?l-caron -> U-uml
        .replaceAll('?ť', 'Ü') // ?t-caron -> U-uml
        .replaceAll('?č', 'ß') // ?c-caron -> sharp-s
        .replaceAll(_strayMarker, '');
  }

  /// Strip leading zeros from standalone number tokens (e.g. house numbers
  /// "097" -> "97"), without touching mid-number zeros, decimals, or numbers
  /// glued to letters.
  static final _leadingZero = RegExp(r'(?<![\w.])0+(\d)');
  static String? _stripLeadingZeros(String? s) =>
      s?.replaceAllMapped(_leadingZero, (m) => m.group(1)!);

  /// Full normalization for address-like fields (encoding repair + leading-zero
  /// cleanup), collapsing the result to null when empty.
  static String? _normalizeAddress(String? s) {
    final repaired = _stripLeadingZeros(_repairEncoding(s))?.trim();
    return (repaired == null || repaired.isEmpty) ? null : repaired;
  }

  /// Look up the owner(s) for a cadastral parcel by KO code ([sifko]) and parcel
  /// number ([parcela], e.g. "1799/89"). Returns null when no database is
  /// imported or no match is found. Fast (indexed) and synchronous.
  OwnerInfo? lookup(int? sifko, String? parcela) {
    if (sifko == null || parcela == null) return null;
    final key = parcela.trim();
    if (key.isEmpty) return null;
    // Public (embedded, redistributable) takes precedence; fall back to the
    // imported/downloaded private database for natural-person owners.
    return _lookupPublic(sifko, key) ?? _lookupPrivate(sifko, key);
  }

  /// Owner(s) + manager(s) from the embedded public database. Managers are
  /// suffixed " (upravljavec)" so they read distinctly from owners. Returns null
  /// when the public DB is absent or has no row for the parcel.
  OwnerInfo? _lookupPublic(int sifko, String key) {
    final db = _publicDb;
    if (db == null) return null;
    try {
      final rows = db.select(
        'SELECT n.naziv AS naziv, o.vloga AS vloga '
        'FROM owners o JOIN names n ON n.id = o.name_id '
        'WHERE o.sifko = ? AND o.parcela = ?',
        [sifko, key],
      );
      if (rows.isEmpty) return null;
      final owners = <String>[];
      final managers = <String>[];
      for (final r in rows) {
        final name = (r['naziv'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        if (r['vloga'] == 'U') {
          if (!managers.contains(name)) managers.add(name);
        } else if (!owners.contains(name)) {
          owners.add(name);
        }
      }
      final all = <String>[
        ...owners,
        for (final m in managers) '$m (upravljavec)',
      ];
      if (all.isEmpty) return null;
      return OwnerInfo(owners: all);
    } catch (e) {
      debugPrint('OwnerLookupService._lookupPublic failed: $e');
      return null;
    }
  }

  /// Category of a publicly owned/managed parcel (state / municipality /
  /// company), or null when the parcel has no public record. Classified from
  /// the owner name(s), preferring owners over managers and state over
  /// municipality over company. Fast (indexed). Used to colour parcels by
  /// owner type on the map.
  PublicOwnerCategory? publicCategory(int? sifko, String? parcela) {
    final db = _publicDb;
    if (db == null || sifko == null || parcela == null) return null;
    final key = parcela.trim();
    if (key.isEmpty) return null;
    try {
      final rows = db.select(
        'SELECT n.naziv AS naziv, o.vloga AS vloga '
        'FROM owners o JOIN names n ON n.id = o.name_id '
        'WHERE o.sifko = ? AND o.parcela = ?',
        [sifko, key],
      );
      if (rows.isEmpty) return null;
      PublicOwnerCategory? owner;
      PublicOwnerCategory? manager;
      for (final r in rows) {
        final name = (r['naziv'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        final c = _classifyOwner(name);
        if (r['vloga'] == 'L') {
          owner = _moreSpecific(owner, c);
        } else {
          manager = _moreSpecific(manager, c);
        }
      }
      return owner ?? manager;
    } catch (e) {
      debugPrint('OwnerLookupService.publicCategory failed: $e');
      return null;
    }
  }

  static PublicOwnerCategory _classifyOwner(String name) {
    final u = name.toUpperCase();
    if (u.contains('REPUBLIKA SLOVENIJA')) return PublicOwnerCategory.state;
    if (u.contains('OBČIN')) return PublicOwnerCategory.obcina; // OBČINA/OBČINE
    return PublicOwnerCategory.company;
  }

  /// Keep the more notable category when a parcel has several owners:
  /// state > municipality > company.
  static PublicOwnerCategory _moreSpecific(
    PublicOwnerCategory? a,
    PublicOwnerCategory b,
  ) {
    if (a == null) return b;
    return a.index <= b.index ? a : b; // enum order: state, obcina, company
  }

  OwnerInfo? _lookupPrivate(int sifko, String key) {
    final db = _db;
    if (db == null) return null;
    try {
      final rows = db.select(
        'SELECT DISTINCT lastnik, naslov, imeko, obcina FROM owners '
        'WHERE sifko = ? AND parcela = ?',
        [sifko, key],
      );
      if (rows.isEmpty) return null;

      final owners = <String>[];
      // Take the first non-empty value of each field. naslov is the owner's
      // residence; imeko is the cadastral municipality (KO) name; obcina is the
      // administrative municipality (sparse in the source).
      String? naslov;
      String? imeko;
      String? obcina;
      for (final row in rows) {
        final name = _repairEncoding((row['lastnik'] as String?)?.trim());
        if (name != null && name.isNotEmpty && !owners.contains(name)) {
          owners.add(name);
        }
        if (naslov == null) {
          final v = _normalizeAddress(row['naslov'] as String?);
          if (v != null) naslov = v;
        }
        if (imeko == null) {
          final v = _normalizeAddress(row['imeko'] as String?);
          if (v != null) imeko = v;
        }
        if (obcina == null) {
          final v = _normalizeAddress(row['obcina'] as String?);
          if (v != null) obcina = v;
        }
      }
      if (owners.isEmpty) return null;
      final addressParts = [?naslov, ?obcina];
      final address = addressParts.isEmpty ? null : addressParts.join(', ');
      return OwnerInfo(
        owners: owners,
        address: address,
        koName: imeko,
        municipality: obcina,
      );
    } catch (e) {
      debugPrint('OwnerLookupService.lookup failed: $e');
      return null;
    }
  }

  /// Cadastral municipality (katastrska občina) name for a [sifko] code, e.g.
  /// 1650 -> "STARI TRG". Returns null when no database is imported or no name
  /// is found. Fast (indexed) and cached, including negative lookups.
  String? koName(int? sifko) {
    final db = _db;
    if (db == null || sifko == null) return null;
    if (_koNameCache.containsKey(sifko)) return _koNameCache[sifko];

    String? name;
    try {
      final rows = db.select(
        "SELECT imeko FROM owners "
        "WHERE sifko = ? AND imeko IS NOT NULL AND imeko != '' LIMIT 1",
        [sifko],
      );
      if (rows.isNotEmpty) {
        final v = (rows.first['imeko'] as String?)?.trim();
        if (v != null && v.isNotEmpty) name = v;
      }
    } catch (e) {
      debugPrint('OwnerLookupService.koName failed: $e');
    }
    _koNameCache[sifko] = name;
    return name;
  }

  /// Shortest search term worth running; trigram indexes need 3 characters.
  static const minQueryLength = 3;

  /// Search owned parcels by owner [name] and/or [address] (both optional,
  /// AND-combined). Returns one hit per parcel (KO + parcela) listing all of
  /// its matching co-owners, for the owner-import flow. Returns no hits when
  /// no database is open, both terms are blank, or a term is shorter than
  /// [minQueryLength] (`tooShort`). Capped at [limit] parcels; `truncated`
  /// says more exist.
  ///
  /// Runs on the calling isolate; the UI uses [searchOwnersAsync].
  OwnerSearchResult searchOwners({
    String? name,
    String? address,
    int limit = 300,
  }) {
    final db = _db;
    if (db == null) return OwnerSearchResult.empty;
    return _search(
      db,
      indexed: _hasSearchIndex,
      name: name,
      address: address,
      limit: limit,
    );
  }

  /// [searchOwners] on a background isolate with its own connection, so a
  /// slow search never blocks the UI.
  Future<OwnerSearchResult> searchOwnersAsync({
    String? name,
    String? address,
    int limit = 300,
  }) async {
    final path = _path;
    if (_db == null || path == null) return OwnerSearchResult.empty;
    final terms = _searchTerms(name, address);
    if (terms == null) return OwnerSearchResult.empty;
    if (terms.tooShort) return OwnerSearchResult.short;
    return _searchInBackground(
      path,
      indexed: _hasSearchIndex,
      name: name,
      address: address,
      limit: limit,
    );
  }

  /// Free-text search over every owner field. Each word of [words] must match
  /// the owner name, the address, or (when it names a KO, see
  /// [OwnerSearchTerm.sifkos]) the KO, in any order and as a substring,
  /// ignoring case and diacritics ("skofja" finds ŠKOFJA LOKA). Words under
  /// [minQueryLength] characters are ignored. [onlySifko] restricts to one KO.
  /// Runs on a background isolate.
  Future<OwnerSearchResult> searchAnyAsync(
    List<OwnerSearchTerm> words, {
    int? onlySifko,
    int limit = 300,
  }) async {
    final path = _path;
    if (_db == null || path == null) return OwnerSearchResult.empty;
    final folded = _foldTerms(words);
    if (folded.isEmpty) {
      return words.isEmpty ? OwnerSearchResult.empty : OwnerSearchResult.short;
    }
    final indexed = _hasSearchIndex;
    return Isolate.run(() {
      final db = sqlite3.open(path);
      try {
        db.execute('PRAGMA busy_timeout = 5000');
        return _searchAny(
          db,
          indexed: indexed,
          terms: folded,
          onlySifko: onlySifko,
          limit: limit,
        );
      } finally {
        db.close();
      }
    });
  }

  static List<OwnerSearchTerm> _foldTerms(List<OwnerSearchTerm> words) => [
        for (final w in words)
          if (foldForSearch(w.text.trim()).length >= minQueryLength)
            OwnerSearchTerm(foldForSearch(w.text.trim()), w.sifkos),
      ];

  static OwnerSearchResult _searchAny(
    Database db, {
    required bool indexed,
    required List<OwnerSearchTerm> terms,
    int? onlySifko,
    required int limit,
  }) {
    final where = <String>[];
    final args = <Object?>[];
    for (final t in terms) {
      final like = '%${_likeEscape(t.text)}%';
      final ko = t.sifkos.isEmpty
          ? ''
          : ' OR sifko IN (${t.sifkos.map((k) => k.toString()).join(',')})';
      if (indexed) {
        where.add(
          "(lastnik IN (SELECT term FROM owner_name_search "
          "WHERE term_f LIKE ? ESCAPE '\\') "
          "OR naslov IN (SELECT term FROM owner_address_search "
          "WHERE term_f LIKE ? ESCAPE '\\')$ko)",
        );
      } else {
        where.add(
          "(${_foldSql('lastnik')} LIKE ? ESCAPE '\\' "
          "OR ${_foldSql('naslov')} LIKE ? ESCAPE '\\'$ko)",
        );
      }
      args..add(like)..add(like);
    }
    if (onlySifko != null) {
      where.add('sifko = ?');
      args.add(onlySifko);
    }
    final rowLimit = limit * 4;
    args.add(rowLimit);
    try {
      final rows = db.select(
        'SELECT DISTINCT sifko, parcela, lastnik, naslov, imeko, obcina '
        'FROM owners WHERE ${where.join(' AND ')} '
        'ORDER BY lastnik, sifko, parcela LIMIT ?',
        args,
      );
      final hits = _groupByParcel(rows);
      return OwnerSearchResult(
        hits: hits.length > limit ? hits.sublist(0, limit) : hits,
        truncated: hits.length > limit || rows.length >= rowLimit,
      );
    } catch (e) {
      debugPrint('OwnerLookupService.searchAny failed: $e');
      return OwnerSearchResult.empty;
    }
  }

  /// Folded, uppercased terms, or null when both are blank. `tooShort` when
  /// a given term is under [minQueryLength] characters.
  static ({String n, String a, bool tooShort})? _searchTerms(
    String? name,
    String? address,
  ) {
    final n = foldForSearch((name ?? '').trim());
    final a = foldForSearch((address ?? '').trim());
    if (n.isEmpty && a.isEmpty) return null;
    final tooShort = (n.isNotEmpty && n.length < minQueryLength) ||
        (a.isNotEmpty && a.length < minQueryLength);
    return (n: n, a: a, tooShort: tooShort);
  }

  static OwnerSearchResult _search(
    Database db, {
    required bool indexed,
    String? name,
    String? address,
    required int limit,
  }) {
    final terms = _searchTerms(name, address);
    if (terms == null) return OwnerSearchResult.empty;
    if (terms.tooShort) return OwnerSearchResult.short;

    // Case- and diacritic-insensitive (ILIKE-style): "kosir" finds KOŠIR,
    // "novakovic" finds NOVAKOVIĆ, also when the source mangled a letter.
    // With the index, the match runs over ~100k distinct folded terms; the
    // fallback folds every owner row and is ~1000x slower.
    final where = <String>[];
    final args = <Object?>[];
    for (final (term, column, table) in [
      (terms.n, 'lastnik', 'owner_name_search'),
      (terms.a, 'naslov', 'owner_address_search'),
    ]) {
      if (term.isEmpty) continue;
      where.add(
        indexed
            ? "$column IN (SELECT term FROM $table WHERE term_f LIKE ? ESCAPE '\\')"
            : "${_foldSql(column)} LIKE ? ESCAPE '\\'",
      );
      args.add('%${_likeEscape(term)}%');
    }
    // A parcel has one row per co-owner, so fetch extra rows to fill
    // [limit] parcels after grouping.
    final rowLimit = limit * 4;
    args.add(rowLimit);

    try {
      final rows = db.select(
        'SELECT DISTINCT sifko, parcela, lastnik, naslov, imeko, obcina '
        'FROM owners WHERE ${where.join(' AND ')} '
        'ORDER BY lastnik, sifko, parcela LIMIT ?',
        args,
      );
      final hits = _groupByParcel(rows);
      return OwnerSearchResult(
        hits: hits.length > limit ? hits.sublist(0, limit) : hits,
        truncated: hits.length > limit || rows.length >= rowLimit,
      );
    } catch (e) {
      debugPrint('OwnerLookupService.searchOwners failed: $e');
      return OwnerSearchResult.empty;
    }
  }

  /// Letters folded to plain ASCII for search, including the mangled
  /// two-character forms the source uses for some of them (see
  /// [_repairEncoding]). Mangled forms come first so their '?' is consumed.
  static const _searchFolds = [
    ('?\u0107', 'C'), // ?ć -> Ć
    ('?\u00EE', 'C'), // ?î -> Č
    ('?á', 'S'),
    ('?Ż', 'Z'),
    ('?É', 'D'),
    ('Č', 'C'),
    ('Ć', 'C'),
    ('Š', 'S'),
    ('Ž', 'Z'),
    ('Đ', 'D'),
    // Lowercase too: SQLite's LIKE ignores case only for ASCII, so folding
    // these makes the match behave like a case-insensitive ILIKE.
    ('č', 'C'),
    ('ć', 'C'),
    ('š', 'S'),
    ('ž', 'Z'),
    ('đ', 'D'),
  ];

  /// Uppercases [s] and folds Slovenian/Croatian letters to ASCII, matching
  /// what [_foldSql] does to the stored column.
  @visibleForTesting
  static String foldForSearch(String s) {
    var out = s.toUpperCase();
    for (final (from, to) in _searchFolds) {
      out = out.replaceAll(from, to);
    }
    return out;
  }

  /// SQL expression folding [column] the same way as [foldForSearch]. Plain
  /// nested REPLACE runs natively, so it adds little to the full-table scan
  /// that LIKE '%…%' already does.
  static String _foldSql(String column) {
    var expr = column;
    for (final (from, to) in _searchFolds) {
      expr = "REPLACE($expr, '$from', '$to')";
    }
    return expr;
  }

  static String _likeEscape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  /// Folds owner rows (one per co-owner) into one hit per KO + parcela,
  /// keeping the order in which each parcel first appears.
  static List<OwnerSearchHit> _groupByParcel(Iterable<Row> rows) {
    final byParcel = <String, _HitBuilder>{};
    for (final r in rows) {
      final sifko = r['sifko'] as int;
      final parcela = r['parcela'] as String;
      final b = byParcel.putIfAbsent(
        '$sifko/$parcela',
        () => _HitBuilder(sifko, parcela),
      );
      final owner = _repairEncoding((r['lastnik'] as String?)?.trim());
      if (owner != null && owner.isNotEmpty && !b.owners.contains(owner)) {
        b.owners.add(owner);
      }
      if (b.address == null) {
        final naslov = _normalizeAddress(r['naslov'] as String?);
        final obcina = _normalizeAddress(r['obcina'] as String?);
        final addr = [?naslov, ?obcina].join(', ');
        if (addr.isNotEmpty) b.address = addr;
      }
      b.koName ??= _normalizeAddress(r['imeko'] as String?);
    }
    return [
      for (final b in byParcel.values)
        OwnerSearchHit(
          sifko: b.sifko,
          parcela: b.parcela,
          owners: b.owners,
          address: b.address,
          koName: b.koName,
        ),
    ];
  }

  /// Reverse lookup: candidate parcels whose (rough) bounding box contains the
  /// WGS84 point [lat]/[lon]. Used as an offline fallback when the online
  /// cadastral lookup is unavailable. Results are ordered by bounding-box area
  /// ascending, so the smallest (most specific) parcel comes first. Returns
  /// empty when no database is imported or it lacks bbox geometry.
  List<OwnerSearchHit> findOwnersAt(double lat, double lon, {int limit = 8}) {
    final db = _db;
    if (db == null || !_hasGeometry) return const [];

    try {
      ResultSet rows;
      try {
        // Prefer the rtree spatial index.
        rows = db.select(
          'SELECT o.sifko, o.parcela, o.lastnik, o.naslov, o.imeko, o.obcina, '
          '(o.max_lon - o.min_lon) * (o.max_lat - o.min_lat) AS area '
          'FROM owners_bbox b JOIN owners o ON o.rowid = b.id '
          'WHERE b.min_lon <= ? AND b.max_lon >= ? '
          'AND b.min_lat <= ? AND b.max_lat >= ? '
          'ORDER BY area ASC LIMIT ?',
          [lon, lon, lat, lat, limit],
        );
      } catch (_) {
        // rtree module/table missing — fall back to the plain bbox columns.
        rows = db.select(
          'SELECT sifko, parcela, lastnik, naslov, imeko, obcina, '
          '(max_lon - min_lon) * (max_lat - min_lat) AS area '
          'FROM owners '
          'WHERE min_lon <= ? AND max_lon >= ? '
          'AND min_lat <= ? AND max_lat >= ? '
          'ORDER BY area ASC LIMIT ?',
          [lon, lon, lat, lat, limit],
        );
      }

      return _groupByParcel(rows);
    } catch (e) {
      debugPrint('OwnerLookupService.findOwnersAt failed: $e');
      return const [];
    }
  }
}

/// One word of a free-text owner search. [sifkos] are the KOs the word names,
/// so a word like "babno" also matches parcels in that KO.
class OwnerSearchTerm {
  final String text;
  final List<int> sifkos;
  const OwnerSearchTerm(this.text, [this.sifkos = const []]);
}

/// One parcel result from an owner search: the cadastral key (KO + parcela)
/// plus its co-owners' repaired names and the first known address.
class OwnerSearchHit {
  final int sifko;
  final String parcela;
  final List<String> owners;
  final String? address;

  /// Cadastral municipality (katastrska občina) name, e.g. "BABNO POLJE".
  final String? koName;

  const OwnerSearchHit({
    required this.sifko,
    required this.parcela,
    required this.owners,
    this.address,
    this.koName,
  });

  /// All co-owners, comma separated (stored on an imported parcel).
  String get owner => owners.join(', ');

  /// "BABNO POLJE (1651)" when the KO name is known, else "1651".
  String get koLabel => koName != null ? '$koName ($sifko)' : '$sifko';
}

/// Result of an owner search.
class OwnerSearchResult {
  const OwnerSearchResult({
    required this.hits,
    this.truncated = false,
    this.tooShort = false,
  });

  static const empty = OwnerSearchResult(hits: []);
  static const short = OwnerSearchResult(hits: [], tooShort: true);

  /// One hit per parcel.
  final List<OwnerSearchHit> hits;

  /// More parcels matched than were returned.
  final bool truncated;

  /// A search term was under [OwnerLookupService.minQueryLength] characters,
  /// so nothing was searched.
  final bool tooShort;
}

class _HitBuilder {
  _HitBuilder(this.sifko, this.parcela);

  final int sifko;
  final String parcela;
  final owners = <String>[];
  String? address;
  String? koName;
}

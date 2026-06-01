import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'aes_file_decryptor.dart';

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

  Database? _db;
  String? _path;
  int _rowCount = 0;
  String? _source; // 'imported' | 'downloaded'

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

  /// Whether an owners database has been imported and opened successfully.
  bool get isAvailable => _db != null;

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

  /// Open the database if it exists. Safe to call on every app start.
  Future<void> init() async {
    try {
      _path = await _targetPath();
      if (!File(_path!).existsSync()) return;
      _open(_path!);
    } catch (e) {
      debugPrint('OwnerLookupService.init failed: $e');
      _close();
    }
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
    _rowCount = _readRowCount(db);
    _hasGeometry = _detectGeometry(db);
    _source = _readSource(path);
    _db = db;
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
        .replaceAll(_strayMarker, '');
  }

  /// Look up the owner(s) for a cadastral parcel by KO code ([sifko]) and parcel
  /// number ([parcela], e.g. "1799/89"). Returns null when no database is
  /// imported or no match is found. Fast (indexed) and synchronous.
  OwnerInfo? lookup(int? sifko, String? parcela) {
    final db = _db;
    if (db == null || sifko == null || parcela == null) return null;
    final key = parcela.trim();
    if (key.isEmpty) return null;

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
          final v = (row['naslov'] as String?)?.trim();
          if (v != null && v.isNotEmpty) naslov = v;
        }
        if (imeko == null) {
          final v = (row['imeko'] as String?)?.trim();
          if (v != null && v.isNotEmpty) imeko = v;
        }
        if (obcina == null) {
          final v = (row['obcina'] as String?)?.trim();
          if (v != null && v.isNotEmpty) obcina = v;
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

  /// Search owned parcels by owner [name] and/or [address] (both optional,
  /// AND-combined). Returns parcels (KO + parcela) with full owner info, for
  /// the owner-import flow. Returns empty when no database, or when both terms
  /// are blank (to avoid dumping the whole table). Capped at [limit].
  List<OwnerSearchHit> searchOwners({
    String? name,
    String? address,
    int limit = 300,
  }) {
    final db = _db;
    if (db == null) return const [];
    // Data is stored uppercase; uppercase the query so caron letters match.
    final n = (name ?? '').trim().toUpperCase();
    final a = (address ?? '').trim().toUpperCase();
    if (n.isEmpty && a.isEmpty) return const [];

    final where = <String>[];
    final args = <Object?>[];
    if (n.isNotEmpty) {
      where.add('lastnik LIKE ?');
      args.add('%$n%');
    }
    if (a.isNotEmpty) {
      where.add('naslov LIKE ?');
      args.add('%$a%');
    }
    args.add(limit);

    try {
      final rows = db.select(
        'SELECT DISTINCT sifko, parcela, lastnik, naslov, imeko, obcina '
        'FROM owners WHERE ${where.join(' AND ')} '
        'ORDER BY lastnik, sifko, parcela LIMIT ?',
        args,
      );
      return rows.map((r) {
        final owner = _repairEncoding((r['lastnik'] as String?)?.trim()) ?? '';
        final naslov = (r['naslov'] as String?)?.trim() ?? '';
        final obcina = (r['obcina'] as String?)?.trim() ?? '';
        final imeko = (r['imeko'] as String?)?.trim() ?? '';
        final addr = [
          if (naslov.isNotEmpty) naslov,
          if (obcina.isNotEmpty) obcina,
        ].join(', ');
        return OwnerSearchHit(
          sifko: r['sifko'] as int,
          parcela: r['parcela'] as String,
          owner: owner,
          address: addr.isEmpty ? null : addr,
          koName: imeko.isEmpty ? null : imeko,
        );
      }).toList();
    } catch (e) {
      debugPrint('OwnerLookupService.searchOwners failed: $e');
      return const [];
    }
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

      return rows.map((r) {
        final owner = _repairEncoding((r['lastnik'] as String?)?.trim()) ?? '';
        final naslov = (r['naslov'] as String?)?.trim() ?? '';
        final obcina = (r['obcina'] as String?)?.trim() ?? '';
        final imeko = (r['imeko'] as String?)?.trim() ?? '';
        final addr = [
          if (naslov.isNotEmpty) naslov,
          if (obcina.isNotEmpty) obcina,
        ].join(', ');
        return OwnerSearchHit(
          sifko: r['sifko'] as int,
          parcela: r['parcela'] as String,
          owner: owner,
          address: addr.isEmpty ? null : addr,
          koName: imeko.isEmpty ? null : imeko,
        );
      }).toList();
    } catch (e) {
      debugPrint('OwnerLookupService.findOwnersAt failed: $e');
      return const [];
    }
  }
}

/// One parcel result from an owner search: the cadastral key (KO + parcela)
/// plus the owner's repaired name and full address.
class OwnerSearchHit {
  final int sifko;
  final String parcela;
  final String owner;
  final String? address;

  /// Cadastral municipality (katastrska občina) name, e.g. "BABNO POLJE".
  final String? koName;

  const OwnerSearchHit({
    required this.sifko,
    required this.parcela,
    required this.owner,
    this.address,
    this.koName,
  });

  /// "BABNO POLJE (1651)" when the KO name is known, else "1651".
  String get koLabel => koName != null ? '$koName ($sifko)' : '$sifko';
}

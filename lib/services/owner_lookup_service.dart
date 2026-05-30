import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Owner(s) + address looked up for a single cadastral parcel.
class OwnerInfo {
  /// Distinct owner names (co-owners), already de-duplicated.
  final List<String> owners;

  /// First non-empty address found for the parcel, if any.
  final String? address;

  const OwnerInfo({required this.owners, this.address});

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

  /// Whether an owners database has been imported and opened successfully.
  bool get isAvailable => _db != null;

  /// Number of owner rows in the imported database (0 when unavailable).
  int get rowCount => _rowCount;

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
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    // Validate it is actually an owners database.
    final hasTable = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='owners'",
    );
    if (hasTable.isEmpty) {
      db.close();
      throw const FormatException('Datoteka ni veljavna baza lastnikov.');
    }
    _rowCount = _readRowCount(db);
    _db = db;
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
  }

  /// Import (copy) a picked `.sqlite` file into the app and open it. Replaces any
  /// previously imported database. Throws [FormatException] with a Slovenian
  /// message when the file is not a valid owners database.
  Future<OwnerImportResult> importFromFile(String sourcePath) async {
    final target = await _targetPath();
    // Validate the source before replacing the current DB.
    final probe = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
    try {
      final ok = probe.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='owners'",
      );
      if (ok.isEmpty) {
        throw const FormatException('Izbrana datoteka ni baza lastnikov.');
      }
    } finally {
      probe.close();
    }

    _close();
    await File(sourcePath).copy(target);
    _path = target;
    _open(target);
    return OwnerImportResult(_rowCount);
  }

  /// Delete the imported database.
  Future<void> remove() async {
    _close();
    final path = _path ?? await _targetPath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
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
        'SELECT DISTINCT lastnik, naslov, obcina FROM owners '
        'WHERE sifko = ? AND parcela = ?',
        [sifko, key],
      );
      if (rows.isEmpty) return null;

      final owners = <String>[];
      // Občina is the owner's municipality but only ~7% of rows have it, and the
      // same owner/parcel can appear both with and without it. Take the first
      // non-empty value of each part so the fuller "NASLOV, OBCINA" is shown
      // whenever the data has it anywhere.
      String? naslov;
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
        if (obcina == null) {
          final v = (row['obcina'] as String?)?.trim();
          if (v != null && v.isNotEmpty) obcina = v;
        }
      }
      if (owners.isEmpty) return null;
      final addressParts = [?naslov, ?obcina];
      final address = addressParts.isEmpty ? null : addressParts.join(', ');
      return OwnerInfo(owners: owners, address: address);
    } catch (e) {
      debugPrint('OwnerLookupService.lookup failed: $e');
      return null;
    }
  }
}

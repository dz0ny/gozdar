import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqlite3/sqlite3.dart';

import 'ko_locator.dart';
import 'parcel_lookup_service.dart';
import 'remote_asset.dart';

/// One house number (hišna številka) from the Slovenian address register.
class AddressHit {
  /// GURS MID of the house number.
  final int id;

  /// House number with its letter suffix, upper case ("12", "12A").
  final String number;

  /// Street name, or null in a settlement that numbers its houses directly.
  final String? street;
  final String settlement;
  final String? municipality;
  final int? postCode;
  final String? postName;

  /// Centroid of the house number, inside the building footprint.
  final LatLng point;

  /// GURS MID of the building that carries the number, when known.
  final int? building;

  const AddressHit({
    required this.id,
    required this.number,
    required this.street,
    required this.settlement,
    required this.municipality,
    required this.postCode,
    required this.postName,
    required this.point,
    required this.building,
  });

  /// "Poljska ulica 15" or "Babno Polje 12".
  String get title => '${street ?? settlement} $number';

  /// "Kranj, 4000 Kranj" or "1386 Stari trg pri Ložu".
  String get subtitle => [
    if (street != null) settlement,
    if (postCode != null) '$postCode ${postName ?? ''}'.trim(),
  ].join(', ');

  @override
  bool operator ==(Object other) => other is AddressHit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A street that matched the typed words, offered to narrow the search.
class StreetHit {
  final int id;
  final String name;
  final String settlement;

  const StreetHit({
    required this.id,
    required this.name,
    required this.settlement,
  });
}

/// A named unit with its folded name, kept in memory for matching.
class _Named {
  final int id;
  final String name;
  final List<String> words;

  /// Settlement of a street (null for a settlement).
  final int? parent;

  _Named(this.id, this.name, this.parent)
    : words = KoLocator.fold(name).split(RegExp(r'[\s\-]+'));

  /// True when every token in [tokens] starts a word of this name.
  bool matches(List<String> tokens) =>
      tokens.every((t) => words.any((w) => w.startsWith(t)));
}

/// Offline lookup of Slovenian house numbers from `addresses.sqlite`, which
/// `tools/parcels/build_addresses.py` builds from the GURS address register.
///
/// The file comes from R2 on first start, in the background, the same way as
/// the public owners database. Until it is there, [isAvailable] is false and
/// the search shows no address rows. The street and settlement names are
/// loaded into memory on first use ([warmUp]); house numbers are read from
/// the database per query.
class AddressLookupService {
  AddressLookupService._();
  static final AddressLookupService instance = AddressLookupService._();

  static const fileName = 'addresses.sqlite';
  static String get url => '${ParcelLookupService.r2BaseUrl}/$fileName';

  /// House numbers have at most three digits and one letter.
  static final houseNumber = RegExp(r'^\d{1,3}[A-Za-z]?$');

  /// Fewest characters worth matching against names.
  static const minQueryLength = 2;

  Database? _db;
  String? _built;
  int _rowCount = 0;
  List<_Named> _settlements = const [];
  List<_Named> _streets = const [];
  Map<int, _Named> _settlementById = const {};
  Map<int, _Named> _streetById = const {};
  Map<int, String> _municipalities = const {};
  Map<int, (int, String)> _posts = const {};

  bool get isAvailable => _db != null;

  /// Build timestamp (`meta.built`) of the open database, or null.
  String? get built => _built;
  int get rowCount => _rowCount;

  /// Open the database when present. Otherwise download it in the
  /// background and open it when it arrives. Returns at once.
  Future<void> init() async {
    try {
      final path = await RemoteAsset.localPath(fileName);
      if (File(path).existsSync()) {
        _open(path);
        return;
      }
      unawaited(_download());
    } catch (e) {
      debugPrint('AddressLookupService.init failed: $e');
      _close();
    }
  }

  Future<void> _download() async {
    final path = await RemoteAsset.ensure(url, fileName);
    if (path == null) return;
    try {
      _open(path);
    } catch (e) {
      debugPrint('AddressLookupService open after download failed: $e');
    }
  }

  /// Download a newer copy and swap it in. Returns false when the download
  /// failed; the old copy stays open in that case.
  Future<bool> refresh({
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final path = await RemoteAsset.ensure(
      url,
      fileName,
      onProgress: onProgress,
      refresh: true,
      beforeSwap: () async => _close(),
      isCancelled: isCancelled,
    );
    if (path == null) {
      if (_db == null) await init();
      return false;
    }
    try {
      _open(path);
      return true;
    } catch (e) {
      debugPrint('AddressLookupService.refresh open failed: $e');
      return false;
    }
  }

  /// Open [path] and load the name tables (tests and [init]).
  @visibleForTesting
  void openForTesting(String path) => _open(path);

  void _open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    final tables = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('addresses','settlements','streets','posts')",
    );
    if (tables.length < 4) {
      db.close();
      throw const FormatException('Neveljavna baza naslovov.');
    }
    String? meta(String key) {
      final r = db.select('SELECT v FROM meta WHERE k=?', [key]);
      return r.isEmpty ? null : r.first['v']?.toString();
    }

    _close();
    _db = db;
    _built = meta('built');
    _rowCount = int.tryParse(meta('rows') ?? '') ?? 0;
  }

  /// Load the name tables now, so the first search does not pay for it.
  /// Runs after the current frame; a no-op without a database.
  void warmUp() {
    if (_db == null || _namesLoaded) return;
    Future(_ensureNames);
  }

  bool _namesLoaded = false;

  /// Read the ~16k settlement, street, municipality and post names into
  /// memory once per open database.
  void _ensureNames() {
    final db = _db;
    if (db == null || _namesLoaded) return;
    final settlements = <_Named>[];
    final byId = <int, _Named>{};
    for (final r in db.select(
      'SELECT id, name, municipality_id FROM settlements',
    )) {
      final s = _Named(
        r['id'] as int,
        r['name'] as String,
        r['municipality_id'] as int?,
      );
      settlements.add(s);
      byId[s.id] = s;
    }
    final streets = [
      for (final r in db.select('SELECT id, name, settlement_id FROM streets'))
        _Named(r['id'] as int, r['name'] as String, r['settlement_id'] as int?),
    ];
    _settlements = settlements;
    _settlementById = byId;
    _streets = streets;
    _streetById = {for (final s in streets) s.id: s};
    _municipalities = {
      for (final r in db.select('SELECT id, name FROM municipalities'))
        r['id'] as int: r['name'] as String,
    };
    _posts = {
      for (final r in db.select('SELECT id, code, name FROM posts'))
        r['id'] as int: (r['code'] as int, r['name'] as String),
    };
    _namesLoaded = true;
  }

  void _close() {
    _db?.close();
    _db = null;
    _built = null;
    _rowCount = 0;
    _namesLoaded = false;
    _settlements = const [];
    _settlementById = const {};
    _streets = const [];
    _streetById = const {};
    _municipalities = const {};
    _posts = const {};
  }

  static List<String> _tokens(String words) => [
    for (final t in KoLocator.fold(words).split(RegExp(r'[\s\-,]+')))
      if (t.isNotEmpty) t,
  ];

  /// Streets whose name, or whose settlement name, the typed [words] match.
  /// Best matches first: a street matched by its own name beats one matched
  /// with the help of its settlement.
  List<StreetHit> streets(String words, {int limit = 6}) {
    final tokens = _tokens(words);
    if (_db == null || tokens.isEmpty || words.trim().length < minQueryLength) {
      return const [];
    }
    _ensureNames();
    final scored = <(int, _Named)>[];
    for (final s in _streets) {
      if (s.matches(tokens)) {
        scored.add((0, s));
        continue;
      }
      final settlement = _settlementById[s.parent];
      if (settlement == null) continue;
      // Every token must start a word of the street or of its settlement,
      // and at least one must come from the street.
      final ok = tokens.every(
        (t) =>
            s.words.any((w) => w.startsWith(t)) ||
            settlement.words.any((w) => w.startsWith(t)),
      );
      if (ok && tokens.any((t) => s.words.any((w) => w.startsWith(t)))) {
        scored.add((1, s));
      }
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      final l = a.$2.name.length.compareTo(b.$2.name.length);
      return l != 0 ? l : a.$2.name.compareTo(b.$2.name);
    });
    return [
      for (final s in scored.take(limit))
        StreetHit(
          id: s.$2.id,
          name: s.$2.name,
          settlement: _settlementById[s.$2.parent]?.name ?? '',
        ),
    ];
  }

  /// House [number] on the streets or in the settlements that [words] name.
  /// A settlement match only lists houses without a street, so "Kranj 12"
  /// does not list the number 12 of every street in Kranj. Hits inside
  /// [preferKo] come first.
  List<AddressHit> search(
    String words,
    String number, {
    KoInfo? preferKo,
    int limit = 10,
  }) {
    final db = _db;
    final tokens = _tokens(words);
    if (db == null || tokens.isEmpty || !houseNumber.hasMatch(number)) {
      return const [];
    }
    _ensureNames();
    final num = number.toUpperCase();
    final out = <AddressHit>[];
    final seen = <int>{};

    void add(ResultSet rows) {
      for (final r in rows) {
        final hit = _hit(r);
        if (seen.add(hit.id)) out.add(hit);
      }
    }

    const select =
        'SELECT id, number, street_id, settlement_id, post_id, lat_e7, '
        'lon_e7, building FROM addresses';
    for (final s in streets(words, limit: 20)) {
      add(db.select('$select WHERE street_id=? AND number=?', [s.id, num]));
    }
    for (final s in _settlements) {
      if (!s.matches(tokens)) continue;
      add(
        db.select(
          '$select WHERE settlement_id=? AND number=? AND street_id IS NULL',
          [s.id, num],
        ),
      );
    }
    if (preferKo != null && out.length > 1) {
      final inside = <AddressHit>[], outside = <AddressHit>[];
      for (final h in out) {
        (KoLocator.instance.koAt(h.point)?.sifko == preferKo.sifko
                ? inside
                : outside)
            .add(h);
      }
      return [...inside, ...outside].take(limit).toList();
    }
    return out.take(limit).toList();
  }

  AddressHit _hit(Row r) {
    final settlement = _settlementById[r['settlement_id'] as int];
    final post = _posts[r['post_id'] as int?];
    return AddressHit(
      id: r['id'] as int,
      number: r['number'] as String,
      street: _streetById[r['street_id'] as int?]?.name,
      settlement: settlement?.name ?? '',
      municipality: _municipalities[settlement?.parent],
      postCode: post?.$1,
      postName: post?.$2,
      point: LatLng((r['lat_e7'] as int) / 1e7, (r['lon_e7'] as int) / 1e7),
      building: r['building'] as int?,
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cache_settings.dart';
import 'cadastral_service.dart';
import 'parcel_lookup_service.dart';

/// One parcel up for sale in a Slovenian court auction (sodna dražba).
class Auction {
  /// Publication id on sodnedrazbe.si (its page is [url]).
  final String id;

  /// "20261028-0104-005", as the court cites it.
  final String publicationId;

  final int sifko;
  final String? koName;
  final String parcela;

  /// Area of the parcel in m², when given.
  final double? area;

  /// Izklicna cena: the price bidding starts at.
  final double? startingPrice;

  /// Ocenjena vrednost: the court's appraisal.
  final double? estimatedPrice;

  /// Share of the parcel being sold, e.g. "1/1" or "1/2".
  final String? share;

  final DateTime saleStartAt;

  /// sodnedrazbe.si status: waiting_start, pending or active.
  final String status;

  final String? court;

  /// "Zemljišča", "Hiše", …
  final String? kind;

  const Auction({
    required this.id,
    required this.publicationId,
    required this.sifko,
    required this.parcela,
    required this.saleStartAt,
    required this.status,
    this.koName,
    this.area,
    this.startingPrice,
    this.estimatedPrice,
    this.share,
    this.court,
    this.kind,
  });

  String get url => 'https://sodnedrazbe.si/single/$id';

  /// Bidding is open right now.
  bool get isActive => status == 'active';

  String get key => '$sifko/$parcela';

  /// An auction from a `/public/publication/list` row, or null for rows
  /// that are not a parcel (movables, rights) or are cancelled.
  @visibleForTesting
  static Auction? fromRow(Map<String, dynamic> r) {
    final sifko = int.tryParse('${r['cadastralMunicipalityCode'] ?? ''}');
    final parcela = (r['parcelNumber'] as String?)?.trim();
    final start = DateTime.tryParse(r['saleStartAt'] as String? ?? '');
    final status = r['status'] as String? ?? '';
    if (sifko == null || parcela == null || parcela.isEmpty) return null;
    if (start == null || status == 'canceled') return null;
    String? text(Object? v) {
      final t = v?.toString().trim();
      return t == null || t.isEmpty ? null : t;
    }

    double? number(Object? v) => double.tryParse(text(v) ?? '');
    String? relation(String key) =>
        text((r[key] as Map<String, dynamic>?)?['valueContent']);

    return Auction(
      id: r['id'] as String,
      publicationId: text(r['publicationId']) ?? '',
      sifko: sifko,
      koName: text(r['cadastralMunicipalityName']),
      parcela: parcela,
      area: number(r['area']),
      startingPrice: number(r['startingPrice']),
      estimatedPrice:
          number(r['estimatedPrice']) ?? number(r['subjectEstimatedPrice']),
      share: text(r['shareInTheBasicLegalPosition']),
      saleStartAt: start,
      status: status,
      court: relation('courtRelation'),
      kind: relation('subjectTypeRelation'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'publicationId': publicationId,
        'sifko': sifko,
        'koName': koName,
        'parcela': parcela,
        'area': area,
        'startingPrice': startingPrice,
        'estimatedPrice': estimatedPrice,
        'share': share,
        'saleStartAt': saleStartAt.toIso8601String(),
        'status': status,
        'court': court,
        'kind': kind,
      };

  static Auction fromJson(Map<String, dynamic> j) => Auction(
        id: j['id'] as String,
        publicationId: j['publicationId'] as String? ?? '',
        sifko: j['sifko'] as int,
        koName: j['koName'] as String?,
        parcela: j['parcela'] as String,
        area: (j['area'] as num?)?.toDouble(),
        startingPrice: (j['startingPrice'] as num?)?.toDouble(),
        estimatedPrice: (j['estimatedPrice'] as num?)?.toDouble(),
        share: j['share'] as String?,
        saleStartAt: DateTime.parse(j['saleStartAt'] as String),
        status: j['status'] as String,
        court: j['court'] as String?,
        kind: j['kind'] as String?,
      );
}

/// Parcels up for sale in Slovenian court auctions, from the public list of
/// sodnedrazbe.si. The whole list (a few hundred parcels) is fetched at most
/// once a day and kept on disk.
class AuctionService extends ChangeNotifier {
  AuctionService._();
  static final AuctionService instance = AuctionService._();

  static const _listUrl =
      'https://api.sodnedrazbe.si/public/publication/list';
  static const _pageSize = 500;
  static const _timeout = Duration(seconds: 30);
  static const _maxAge = Duration(days: 1);
  static const _cacheFile = 'auctions_cache.json';
  static const _visibleKey = 'auctions.visible';

  List<Auction> _auctions = const [];
  Map<String, List<Auction>> _byParcel = const {};
  DateTime? _fetchedAt;
  Future<void>? _loading;
  bool _visible = false;

  /// Whether parcel [parcela] of KO [sifko] is up for auction, from the list
  /// already loaded (see [ensureLoaded]).
  bool isForSale(int sifko, String parcela) =>
      _byParcel.containsKey('$sifko/${parcela.trim()}');

  /// Every current parcel auction, soonest sale first.
  List<Auction> get all => _auctions;

  /// Outlines of auction parcels in the downloaded regions, for the map.
  List<CadastralParcel> get outlines => _outlines;
  List<CadastralParcel> _outlines = const [];
  Set<String>? _outlinedFiles;

  /// Looks up outlines in the offline regions; again only when the set of
  /// downloaded regions changed. Cheap: one indexed query per parcel.
  void refreshOutlines() {
    final lookup = ParcelLookupService.instance;
    final files = lookup.loadedFiles;
    if (_outlinedFiles != null &&
        _outlinedFiles!.length == files.length &&
        _outlinedFiles!.containsAll(files)) {
      return;
    }
    _outlinedFiles = files;
    _outlines = [
      for (final key in _byParcel.keys)
        ?lookup.byNumber(
          _byParcel[key]!.first.sifko,
          _byParcel[key]!.first.parcela,
        ),
    ];
    notifyListeners();
  }

  /// Whether the auctions layer is on (map layer selector).
  bool get visible => _visible;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _visible = prefs.getBool(_visibleKey) ?? false;
  }

  Future<void> setVisible(bool visible) async {
    if (_visible == visible) return;
    _visible = visible;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visibleKey, visible);
  }

  /// Current auctions of parcel [parcela] in KO [sifko]; empty when none.
  Future<List<Auction>> forParcel(int sifko, String parcela) async {
    await ensureLoaded();
    return _byParcel['$sifko/${parcela.trim()}'] ?? const [];
  }

  /// Loads the cached list, refetching it when it is a day old. Never
  /// throws; an old list beats none when sodnedrazbe.si is unreachable.
  Future<void> ensureLoaded() {
    final fresh = _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _maxAge;
    if (fresh) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final useCache = CacheSettings.instance.httpEnabled;
    Map<String, dynamic>? stored;
    if (useCache && _fetchedAt == null) {
      stored = await _read();
      if (stored != null) _apply(stored);
      final fresh = _fetchedAt != null &&
          DateTime.now().difference(_fetchedAt!) < _maxAge;
      if (fresh) return;
    }
    final rows = await _fetchAll();
    if (rows == null) return;
    final auctions = [
      for (final r in rows) ?Auction.fromRow(r),
    ];
    _setAuctions(auctions, DateTime.now());
    if (useCache) unawaited(_write());
  }

  Future<List<Map<String, dynamic>>?> _fetchAll() async {
    final rows = <Map<String, dynamic>>[];
    try {
      var offset = 0;
      while (true) {
        final res = await http
            .post(
              Uri.parse(_listUrl),
              // The API answers 500 without an Accept header.
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'pagination': {'offset': offset, 'limit': _pageSize},
              }),
            )
            .timeout(_timeout);
        if (res.statusCode != 200) return null;
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
        final page = (body['list'] as List).cast<Map<String, dynamic>>();
        rows.addAll(page);
        final total = (body['pagination'] as Map?)?['countAll'] as int? ?? 0;
        offset += _pageSize;
        if (page.length < _pageSize || offset >= total) return rows;
      }
    } catch (e) {
      debugPrint('AuctionService fetch failed: $e');
      return null;
    }
  }

  void _setAuctions(List<Auction> auctions, DateTime fetchedAt) {
    _auctions = auctions..sort((a, b) => a.saleStartAt.compareTo(b.saleStartAt));
    _fetchedAt = fetchedAt;
    final byParcel = <String, List<Auction>>{};
    for (final a in auctions) {
      byParcel.putIfAbsent(a.key, () => []).add(a);
    }
    _byParcel = byParcel;
    _outlinedFiles = null;
    refreshOutlines();
    notifyListeners();
  }

  Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_cacheFile');

  Future<Map<String, dynamic>?> _read() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AuctionService cache read failed: $e');
      return null;
    }
  }

  void _apply(Map<String, dynamic> stored) {
    final at = DateTime.tryParse(stored['fetchedAt'] as String? ?? '');
    final list = stored['auctions'] as List?;
    if (at == null || list == null) return;
    _setAuctions(
      [for (final j in list.cast<Map<String, dynamic>>()) Auction.fromJson(j)],
      at,
    );
  }

  Future<void> _write() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'fetchedAt': _fetchedAt?.toIso8601String(),
        'auctions': [for (final a in _auctions) a.toJson()],
      }));
    } catch (e) {
      debugPrint('AuctionService cache write failed: $e');
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'cache_settings.dart';
import 'hr_owner_service.dart';

/// One valuation model on a parcel (forest, farmland, …) and its part of
/// the parcel's value.
class ValuationPart {
  /// GURS model code: GOZ, KME, STZ, ZPS or DRZ.
  final String model;

  /// Share of the parcel's area, 0–100.
  final double sharePercent;

  /// Value of this part in €, rounded as GURS publishes it.
  final int value;

  /// Value level within the model, e.g. "6/10".
  final String? level;

  const ValuationPart({
    required this.model,
    required this.sharePercent,
    required this.value,
    this.level,
  });

  /// Land under a building: its value is counted with the building.
  bool get isUnderBuilding => model == 'ZPS';
}

/// GURS posplošena tržna vrednost of a Slovenian parcel.
class ParcelValuation {
  final int sifko;
  final String parcela;

  /// GURS parcel id, for the link to vrednotenje.gov.si.
  final int pcMid;

  /// Area in m².
  final double area;

  final List<ValuationPart> parts;

  /// Forest factors, only set for forest land.
  final int? boniteta;
  final int? siteIndex;
  final int? openness;

  /// When GURS calculated the values.
  final DateTime? modelDate;

  const ParcelValuation({
    required this.sifko,
    required this.parcela,
    required this.pcMid,
    required this.area,
    required this.parts,
    this.boniteta,
    this.siteIndex,
    this.openness,
    this.modelDate,
  });

  /// Value of the land itself; land under a building is valued with the
  /// building and left out.
  int get total =>
      parts.where((p) => !p.isUnderBuilding).fold(0, (sum, p) => sum + p.value);

  /// Area that [total] covers.
  double get valuedArea =>
      area *
      parts
          .where((p) => !p.isUnderBuilding)
          .fold(0.0, (sum, p) => sum + p.sharePercent) /
      100;

  /// € per m² of valued land, or null when nothing is valued.
  double? get perSquareMeter =>
      total > 0 && valuedArea > 0 ? total / valuedArea : null;

  /// GURS has no value for the parcel's land (other than land under a
  /// building, which is valued with the building).
  bool get isUnvalued => total == 0;

  bool get isForest => parts.any((p) => p.model == 'GOZ');

  String get gursUrl => 'https://vrednotenje.gov.si/EV_JV/#/parcela_$pcMid';
}

/// Generalised market value (posplošena tržna vrednost) of Slovenian
/// parcels from the public GURS valuation register (vrednotenje.gov.si).
/// Every answer is kept on disk with no expiry, so a parcel is asked about
/// once; misses are not cached.
class SiValuationService {
  SiValuationService._();
  static final SiValuationService instance = SiValuationService._();

  static const _base = 'https://vrednotenje.gov.si/EV_Javni_Server';
  static const _timeout = Duration(seconds: 20);

  static const _cacheFile = 'si_valuation_cache.json';

  /// Lookups in flight or answered this session.
  final _cache = <String, Future<ParcelValuation?>>{};

  /// Answers kept on disk, keyed like [_cache]; loaded on first use.
  Map<String, dynamic>? _stored;
  Future<Map<String, dynamic>>? _loading;

  /// Model dates by model version, fetched once per session.
  Future<Map<String, dynamic>?>? _modelDates;

  /// The register covers Slovenian KOs only.
  static bool covers(int? sifko) =>
      sifko != null && sifko > 0 && !HrOwnerService.isCroatianKo(sifko);

  /// Valuation of parcel [parcela] in KO [sifko], or null when the parcel
  /// is unknown or the register is unreachable with nothing cached.
  Future<ParcelValuation?> lookup(int sifko, String parcela) {
    final key = '$sifko/${parcela.trim()}';
    final pending = _cache[key];
    if (pending != null) return pending;
    final future = _cachedOrFetch(key, sifko, parcela.trim());
    _cache[key] = future;
    // Forget misses (_fetch never throws) so the next look retries.
    future.then((v) {
      if (v == null) _cache.remove(key);
    });
    return future;
  }

  Future<ParcelValuation?> _cachedOrFetch(
    String key,
    int sifko,
    String parcela,
  ) async {
    // The HTTP cache switch in About covers this cache too.
    final useCache = CacheSettings.instance.httpEnabled;
    final stored = await _load();
    final hit = useCache ? stored[key] : null;
    if (hit is Map<String, dynamic>) {
      final cached = _fromJson(hit);
      if (cached != null) return cached;
    }
    final raw = await _fetch(sifko, parcela);
    if (raw == null) return null;
    if (useCache) {
      stored[key] = raw;
      unawaited(_save(stored));
    }
    return _fromJson(raw);
  }

  Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_cacheFile');

  Future<Map<String, dynamic>> _load() {
    final stored = _stored;
    if (stored != null) return Future.value(stored);
    return _loading ??= () async {
      Map<String, dynamic> map = {};
      try {
        final file = await _file();
        if (file.existsSync()) {
          map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('SiValuationService cache read failed: $e');
      }
      return _stored = map;
    }();
  }

  Future<void> _save(Map<String, dynamic> stored) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(stored));
    } catch (e) {
      debugPrint('SiValuationService cache write failed: $e');
    }
  }

  static ParcelValuation? _fromJson(Map<String, dynamic> j) {
    try {
      return parse(
        j['parcel'] as Map<String, dynamic>,
        (j['values'] as List<dynamic>).cast<Map<String, dynamic>>(),
        modelDates: j['modelDates'] as Map<String, dynamic>?,
      );
    } catch (e) {
      debugPrint('SiValuationService cached entry unreadable: $e');
      return null;
    }
  }

  /// The raw register answers for a parcel, as stored in the cache: the
  /// search row, the value rows and the dates of their models.
  Future<Map<String, dynamic>?> _fetch(int sifko, String parcela) async {
    try {
      final parcel = await _search(sifko, parcela);
      if (parcel == null) return null;
      final pcMid = parcel['pcMid'];
      final res = await http
          .get(
            Uri.parse(
              '$_base/podatki/parcela/$pcMid/vrednost?expandOkoliscine=false',
            ),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final values = (jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final dates = await (_modelDates ??= _fetchModelDates());
      if (dates == null) _modelDates = null;
      final versions = {for (final v in values) '${v['idModelVer']}'};
      return {
        'parcel': parcel,
        'values': [for (final v in values) _slim(v)],
        'modelDates': {
          for (final ver in versions)
            if (dates?[ver] != null) ver: dates![ver],
        },
      };
    } catch (e) {
      debugPrint('SiValuationService.lookup($sifko, $parcela) failed: $e');
      return null;
    }
  }

  /// The search row for a KO + parcel number ("100/1" for a sub-parcel,
  /// "*22" for a building plot), matched exactly.
  Future<Map<String, dynamic>?> _search(int sifko, String parcela) async {
    final uri = Uri.parse('$_base/podatki/parcela/search').replace(
      queryParameters: {
        'count': '5',
        'offset': '0',
        'parcela': parcela,
        'koSifko': '$sifko',
      },
    );
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final rows = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    for (final r in rows.cast<Map<String, dynamic>>()) {
      if ((r['parcela'] ?? '').toString().trim() == parcela) return r;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchModelDates() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/system/datumModelov'))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('SiValuationService model dates failed: $e');
      return null;
    }
  }

  /// Only the fields [parse] reads, so the cache stays small.
  static Map<String, dynamic> _slim(Map<String, dynamic> v) => {
    'model': v['model'],
    'delezPov': v['delezPov'],
    'posplosenaVrednost': v['posplosenaVrednost'],
    'raven': v['raven'],
    'napakaOpis': v['napakaOpis'],
    'idModelVer': v['idModelVer'],
  };

  /// Valuation from a `/podatki/parcela/search` row and its
  /// `/podatki/parcela/{pcMid}/vrednost` rows. [modelDates] maps model
  /// versions to epoch milliseconds (`/system/datumModelov`).
  @visibleForTesting
  static ParcelValuation parse(
    Map<String, dynamic> parcel,
    List<Map<String, dynamic>> values, {
    Map<String, dynamic>? modelDates,
  }) {
    final parts = <ValuationPart>[];
    DateTime? modelDate;
    for (final v in values) {
      final model = (v['model'] as String?)?.trim();
      if (model == null || model.isEmpty) continue;
      // A row GURS could not calculate counts as no value.
      final failed = v['napakaOpis'] != null;
      final value = failed ? 0 : (v['posplosenaVrednost'] as num?)?.round();
      parts.add(
        ValuationPart(
          model: model,
          sharePercent: (v['delezPov'] as num?)?.toDouble() ?? 100,
          value: value ?? 0,
          level: (v['raven'] as String?)?.trim(),
        ),
      );
      final ms = modelDates?['${v['idModelVer']}'];
      if (ms is num) {
        final date = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
        if (modelDate == null || date.isAfter(modelDate)) modelDate = date;
      }
    }
    final forest = parts.any((p) => p.model == 'GOZ');
    return ParcelValuation(
      sifko: (parcel['koSifko'] as num).toInt(),
      parcela: (parcel['parcela'] as String).trim(),
      pcMid: (parcel['pcMid'] as num).toInt(),
      area: (parcel['povrsina'] as num?)?.toDouble() ?? 0,
      parts: parts,
      boniteta: (parcel['boniteta'] as num?)?.toInt(),
      siteIndex: forest ? (parcel['rk'] as num?)?.toInt() : null,
      openness: forest ? (parcel['odprtost'] as num?)?.toInt() : null,
      modelDate: modelDate,
    );
  }
}

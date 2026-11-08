import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cache_settings.dart';
import 'lookup_cache_store.dart';
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

/// One part of a building (delStavbe: a house, a flat, a garage) and its
/// value. GURS values a part together with its share of the land under the
/// building.
class BuildingPartValue {
  /// GURS model code: HIS, STA, KDS, GAR, …
  final String? model;

  /// Value in €, or null when GURS could not calculate it.
  final int? value;

  const BuildingPartValue({this.model, this.value});
}

/// A building on a Slovenian parcel and the value of its parts.
class BuildingValuation {
  /// GURS building id.
  final int staSid;

  /// Building number within the KO (številka stavbe).
  final int? number;

  /// Year it was built.
  final int? year;

  /// Land under the whole building, and the part of it on this parcel, m².
  final double footprint;
  final double footprintHere;

  /// Every part, unless there are more than [partCount] can show.
  final List<BuildingPartValue> parts;

  /// How many parts the building has; more than [parts] when there were too
  /// many to look up.
  final int partCount;

  const BuildingValuation({
    required this.staSid,
    this.number,
    this.year,
    required this.footprint,
    required this.footprintHere,
    required this.parts,
    required this.partCount,
  });

  /// Every part was looked up.
  bool get hasAllParts => parts.length == partCount;

  /// Value of the building with the land under it, or null when a part has
  /// no value or was not looked up.
  int? get value {
    if (!hasAllParts || parts.isEmpty) return null;
    var sum = 0;
    for (final p in parts) {
      if (p.value == null) return null;
      sum += p.value!;
    }
    return sum;
  }

  /// The building stands also on other parcels: its value is the whole
  /// building's, not only this parcel's.
  bool get spansParcels => footprint > 0 && footprintHere < footprint - 0.5;

  /// Model codes of its parts, most common first.
  List<String> get models {
    final counts = <String, int>{};
    for (final p in parts) {
      if (p.model != null) counts[p.model!] = (counts[p.model!] ?? 0) + 1;
    }
    return (counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!)));
  }
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

  /// Buildings standing on the parcel.
  final List<BuildingValuation> buildings;

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
    this.buildings = const [],
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

  /// Value of the buildings that stand only on this parcel, each with the
  /// land under it. A building that spans parcels, or has a part without a
  /// value, is left out.
  int get buildingsTotal => buildings
      .where((b) => !b.spansParcels)
      .fold(0, (sum, b) => sum + (b.value ?? 0));

  /// The land and the buildings on it.
  int get totalWithBuildings => total + buildingsTotal;

  /// GURS has no value for the parcel's land nor for a building on it.
  bool get isUnvalued => totalWithBuildings == 0;

  bool get isForest => parts.any((p) => p.model == 'GOZ');

  String get gursUrl => 'https://vrednotenje.gov.si/EV_JV/#/parcela_$pcMid';
}

/// Generalised market value (posplošena tržna vrednost) of Slovenian
/// parcels from the public GURS valuation register (vrednotenje.gov.si).
/// Buildings on the parcel come with the value of their parts. A complete
/// answer is kept on disk with no expiry, so a parcel is asked about once;
/// misses, and answers with a building that could not be read, are not
/// cached.
class SiValuationService {
  SiValuationService._();
  static final SiValuationService instance = SiValuationService._();

  static const _base = 'https://vrednotenje.gov.si/EV_Javni_Server';
  static const _timeout = Duration(seconds: 20);

  /// Rows hold the raw register answer (`parcel`, `values`, `modelDates`,
  /// `buildings`), keyed `sifko/parcela`. Bump the version to drop them all.
  /// 2: buildings on the parcel.
  static final _store = LookupCacheStore(
    'si_valuation',
    version: 2,
    legacyFiles: const ['si_valuation_cache.json'],
  );

  /// Past this many buildings on a parcel, or parts in a building, the
  /// lookup would be too slow to wait for; GURS's page has the rest.
  static const _maxBuildings = 6;
  static const _maxParts = 12;

  /// Lookups in flight or answered this session.
  final _cache = <String, Future<ParcelValuation?>>{};

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
    final answer = _cachedOrFetch(key, sifko, parcela.trim());
    final future = answer.then((a) => a.valuation);
    _cache[key] = future;
    // Forget misses and incomplete answers (_fetch never throws) so the
    // next look retries.
    answer.then((a) {
      if (a.valuation == null || !a.complete) _cache.remove(key);
    });
    return future;
  }

  Future<({ParcelValuation? valuation, bool complete})> _cachedOrFetch(
    String key,
    int sifko,
    String parcela,
  ) async {
    // The HTTP cache switch in About covers this cache too.
    final useCache = CacheSettings.instance.httpEnabled;
    if (useCache) {
      final hit = await _store.read(key);
      final cached = hit == null ? null : _fromJson(hit);
      if (cached != null) return (valuation: cached, complete: true);
    }
    final raw = await _fetch(sifko, parcela);
    if (raw == null) return (valuation: null, complete: false);
    final complete = raw['complete'] == true;
    raw.remove('complete');
    if (useCache && complete) unawaited(_store.write(key, raw));
    return (valuation: _fromJson(raw), complete: complete);
  }

  static ParcelValuation? _fromJson(Map<String, dynamic> j) {
    try {
      return parse(
        j['parcel'] as Map<String, dynamic>,
        (j['values'] as List<dynamic>).cast<Map<String, dynamic>>(),
        modelDates: j['modelDates'] as Map<String, dynamic>?,
        buildings: (j['buildings'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      debugPrint('SiValuationService cached entry unreadable: $e');
      return null;
    }
  }

  /// The raw register answers for a parcel, as stored in the cache: the
  /// search row, the value rows, the dates of their models and the
  /// buildings, with `complete` false when a building could not be read.
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
      final buildings = await _buildings(pcMid);
      return {
        'complete': buildings.complete,
        'buildings': buildings.read,
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

  /// GET [path] on the register as JSON, or null on any other answer.
  Future<Object?> _get(String path) async {
    final res = await http.get(Uri.parse('$_base$path')).timeout(_timeout);
    if (res.statusCode != 200) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// The buildings on parcel [pcMid] that could be read, as [parseBuilding]
  /// reads them; [complete] is false when one of them, or the list, could
  /// not be read.
  Future<({List<Map<String, dynamic>> read, bool complete})> _buildings(
    Object? pcMid,
  ) async {
    const none = (read: <Map<String, dynamic>>[], complete: false);
    try {
      final links = await _get('/podatki/parcela/$pcMid/staPar');
      if (links is! List) return none;
      final read = await Future.wait([
        for (final link in links.cast<Map<String, dynamic>>().take(
          _maxBuildings,
        ))
          _building(link).catchError((Object e) {
            debugPrint('SiValuationService building ${link['staSid']}: $e');
            return null;
          }),
      ]);
      return (read: [for (final b in read) ?b], complete: !read.contains(null));
    } catch (e) {
      debugPrint('SiValuationService buildings of $pcMid failed: $e');
      return none;
    }
  }

  /// One building on the parcel: its row, the area of it on the parcel and
  /// the value of each part. Null when a request failed.
  Future<Map<String, dynamic>?> _building(Map<String, dynamic> link) async {
    final staSid = link['staSid'];
    final answers = await Future.wait([
      _get('/podatki/stavba/$staSid'),
      _get('/podatki/stavba/$staSid/delStavbe'),
    ]);
    final building = answers[0];
    final parts = answers[1];
    if (building is! Map<String, dynamic> || parts is! List) return null;
    final rows = parts.cast<Map<String, dynamic>>();
    final values = rows.length > _maxParts
        ? const <Object?>[]
        : await Future.wait([
            for (final p in rows)
              _get('/podatki/delStavbe/${p['dstSid']}/vrednost'),
          ]);
    if (values.any((v) => v is! Map<String, dynamic>)) return null;
    return {
      'staSid': staSid,
      'stevStavbe': building['stevStavbe'],
      'letoIzgSta': building['letoIzgSta'],
      'zemPodStavbo': building['zemPodStavbo'],
      'povrsinaNaParceli': link['povrsina'],
      'partCount': rows.length,
      'parts': [
        for (final v in values.cast<Map<String, dynamic>>())
          {
            'model': v['model'],
            'vrednost': v['vrednost'],
            'napakaOpis': v['napakaOpis'],
          },
      ],
    };
  }

  /// A building from the map [_building] stores.
  @visibleForTesting
  static BuildingValuation parseBuilding(Map<String, dynamic> b) {
    final parts = [
      for (final p
          in (b['parts'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
        BuildingPartValue(
          model: (p['model'] as String?)?.trim(),
          value: p['napakaOpis'] != null
              ? null
              : (p['vrednost'] as num?)?.round(),
        ),
    ];
    return BuildingValuation(
      staSid: (b['staSid'] as num).toInt(),
      number: (b['stevStavbe'] as num?)?.toInt(),
      year: (b['letoIzgSta'] as num?)?.toInt(),
      footprint: (b['zemPodStavbo'] as num?)?.toDouble() ?? 0,
      footprintHere: (b['povrsinaNaParceli'] as num?)?.toDouble() ?? 0,
      parts: parts,
      partCount: (b['partCount'] as num?)?.toInt() ?? parts.length,
    );
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
    List<Map<String, dynamic>> buildings = const [],
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
      buildings: [for (final b in buildings) parseBuilding(b)],
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cache_settings.dart';
import 'ko_locator.dart';
import 'lookup_cache_store.dart';
import 'owner_lookup_service.dart';

/// Owners found for a parcel, and whether the answer is complete enough to
/// cache: false when a ZK unit the parcel links to could not be read.
typedef HrOwnerAnswer = ({OwnerInfo? info, bool complete});

/// A cached Croatian parcel whose holders matched [HrOwnerService.searchCached].
class HrOwnerHit {
  const HrOwnerHit(this.sifko, this.parcela, this.info);

  final int sifko;
  final String parcela;
  final OwnerInfo info;
}

/// Owners of a Croatian parcel, fetched from the public DGU portal
/// (oss.uredjenazemlja.hr). The land registry (zemljišna knjiga, sheet B)
/// is the legal record of ownership, so its owners come first; the cadastre
/// holders (posjednici) are used only when the parcel has no ZK unit or the
/// ZK request fails. A complete answer is kept on disk with no expiry, so a
/// parcel is asked about once. Misses, and answers with a ZK unit that could
/// not be read, are not cached, so the next look asks again.
class HrOwnerService {
  HrOwnerService._();
  static final HrOwnerService instance = HrOwnerService._();

  static const _portal = 'oss.uredjenazemlja.hr';
  static const _base = 'https://$_portal/oss/public';

  /// The portal's public page of a ZK unit ("Pregled ZK uloška").
  @visibleForTesting
  static Uri lrUnitUrl(int mainBookId, String lrUnitNumber) => Uri.https(
    _portal,
    '/public-services/review-lr-bdc',
    {'mainBookId': '$mainBookId', 'lrUnitNumber': lrUnitNumber},
  );

  /// The portal's map zoomed to the parcel of a `/cad/parcel-info`
  /// response, with its cadastre and ZK tabs; null without the ids.
  @visibleForTesting
  static Uri? parcelMapUrl(Map<String, dynamic> parcelInfo) {
    final id = parcelInfo['parcelId']?.toString();
    final number = parcelInfo['parcelNumber']?.toString().trim();
    final ko = parcelInfo['cadMunicipalityRegNum']?.toString();
    if (id == null || number == null || number.isEmpty || ko == null) {
      return null;
    }
    return Uri.https(_portal, '/map', {
      'parcelId': id,
      'parcelNumber': number,
      'cadMunicipalityRegNum': ko,
    });
  }

  // parcel-info routinely takes 15-30 s; a short timeout drops answers
  // that would have arrived.
  static const _timeout = Duration(seconds: 60);

  /// Sent as the portal's own web app does, so the API treats us like a
  /// browser on oss.uredjenazemlja.hr.
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
        'Mobile/15E148 Safari/604.1',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'hr',
    'Origin': 'https://oss.uredjenazemlja.hr',
    'Referer': 'https://oss.uredjenazemlja.hr/',
  };

  /// One keep-alive connection for the search + parcel-info pair, like a
  /// browser tab.
  final _client = http.Client();

  /// The register's placeholder address for a holder whose residence is
  /// unknown; not worth showing.
  static const _unknownAddress = 'NEPOZNATO BORAVIŠTE';

  /// Rows hold [_toJson] answers keyed `sifko/parcela`, searchable by
  /// [_searchText]. Bump the version to drop them all. 2: owners from the
  /// ZK; answers before it were cadastre holders only, often not the owner.
  /// 3: each answer names its source. 4: drops cadastre answers cached
  /// after a failed ZK request.
  static final _store = LookupCacheStore(
    'hr_owners',
    version: 4,
    legacyFiles: const ['hr_owners_cache.json'],
  );

  /// A parcel split across several ZK parcels links to as many units; past
  /// this many the lookup would be too slow to wait for.
  static const _maxLrUnits = 4;

  /// Lookups in flight or answered this session.
  final _cache = <String, Future<OwnerInfo?>>{};

  /// Croatian KO matični brojevi are six digits; Slovenian šifre KO stay
  /// below 10000, so the number alone tells the countries apart.
  static bool isCroatianKo(int? sifko) => sifko != null && sifko >= 100000;

  /// Holders of parcel [parcela] in KO [sifko], or null when the parcel is
  /// unknown or the service is unreachable. [parcelId] is DGU's CESTICA_ID
  /// when known (offline regions store it as `eid`); it saves one request.
  Future<OwnerInfo?> lookup(int sifko, String parcela, {String? parcelId}) {
    final key = '$sifko/${parcela.trim()}';
    final pending = _cache[key];
    if (pending != null) return pending;
    final answer = _cachedOrFetch(key, sifko, parcela.trim(), parcelId);
    final future = answer.then((a) => a.info);
    _cache[key] = future;
    // Forget misses and incomplete answers (_fetch never throws) so the
    // next look retries.
    answer.then((a) {
      if (a.info == null || !a.complete) _cache.remove(key);
    });
    return future;
  }

  Future<HrOwnerAnswer> _cachedOrFetch(
    String key,
    int sifko,
    String parcela,
    String? parcelId,
  ) async {
    // The HTTP cache switch in About covers this cache too.
    final useCache = CacheSettings.instance.httpEnabled;
    if (useCache) {
      final hit = await _read(key);
      if (hit != null) return (info: hit, complete: true);
    }
    final answer = await _fetch(sifko, parcela, parcelId);
    final info = answer.info;
    if (info != null && answer.complete && useCache) {
      unawaited(_write(key, info));
    }
    return answer;
  }

  Future<OwnerInfo?> _read(String key) async {
    final hit = await _store.read(key);
    return hit == null ? null : _fromJson(hit);
  }

  Future<void> _write(String key, OwnerInfo info) =>
      _store.write(key, _toJson(info), search: _searchText(info));

  /// Folded holder names, addresses and KO name, as [searchCached] matches.
  static String _searchText(OwnerInfo info) => KoLocator.fold(
    [
      ...info.owners,
      for (final h in info.holders) h.address ?? '',
      info.koName ?? '',
    ].join(' '),
  );

  /// Stores [entries] (raw `sifko/parcela` → answer JSON) as cached answers,
  /// for tests.
  @visibleForTesting
  Future<void> debugStore(Map<String, Map<String, dynamic>> entries) async {
    for (final e in entries.entries) {
      await _write(e.key, _fromJson(e.value));
    }
  }

  /// Cached parcels whose holder names, addresses or KO name contain every
  /// word of [words] (any order, ignoring case and diacritics). DGU has no
  /// search by owner, so parcels looked up before are the only way back from
  /// a name to its parcels. Words under 3 characters are ignored; none left
  /// means no hits. [onlySifko] restricts to one KO.
  Future<List<HrOwnerHit>> searchCached(
    List<String> words, {
    int? onlySifko,
    int limit = 15,
  }) async {
    final terms = [
      for (final w in words)
        if (w.trim().length >= 3) KoLocator.fold(w.trim()),
    ];
    if (terms.isEmpty) return const [];
    final rows = await _store.search(
      terms,
      keyPrefix: onlySifko == null ? null : '$onlySifko/',
      limit: limit,
    );
    final hits = <HrOwnerHit>[];
    for (final row in rows) {
      // Keys are "sifko/parcela", as in [lookup].
      final slash = row.key.indexOf('/');
      if (slash <= 0) continue;
      final sifko = int.tryParse(row.key.substring(0, slash));
      if (sifko == null) continue;
      hits.add(
        HrOwnerHit(sifko, row.key.substring(slash + 1), _fromJson(row.payload)),
      );
    }
    return hits;
  }

  static Map<String, dynamic> _toJson(OwnerInfo info) => {
    'koName': info.koName,
    'sources': [for (final src in info.sources) src.toJson()],
    'address': info.address,
    'holders': [
      for (final name in info.owners)
        {
          'name': name,
          'share': info.holder(name).share,
          'address': info.holder(name).address,
        },
    ],
  };

  static OwnerInfo _fromJson(Map<String, dynamic> j) {
    final holders = [
      for (final h
          in (j['holders'] as List<dynamic>).cast<Map<String, dynamic>>())
        OwnerHolder(
          h['name'] as String,
          share: h['share'] as String?,
          address: h['address'] as String?,
        ),
    ];
    return OwnerInfo(
      owners: [for (final h in holders) h.name],
      holders: holders,
      address: j['address'] as String?,
      koName: j['koName'] as String?,
      sources: [
        for (final src in j['sources'] as List<dynamic>? ?? const [])
          ?OwnerSource.fromJson(src),
      ],
    );
  }

  Future<HrOwnerAnswer> _fetch(
    int sifko,
    String parcela,
    String? parcelId,
  ) async {
    const miss = (info: null, complete: false);
    try {
      Map<String, dynamic>? json;
      if (parcelId != null && int.tryParse(parcelId) != null) {
        final byId = await _parcelInfo(parcelId);
        // Trust a passed-in id only when it really is this parcel.
        if (byId != null &&
            byId['cadMunicipalityRegNum']?.toString() == '$sifko' &&
            byId['parcelNumber']?.toString().trim() == parcela) {
          json = byId;
        }
      }
      if (json == null) {
        final id = await _parcelId(sifko, parcela);
        if (id == null) return miss;
        json = await _parcelInfo(id);
      }
      if (json == null) return miss;
      final parcelInfo = json;
      final units = lrUnitsOf(parcelInfo).take(_maxLrUnits).toList();
      final answers = await Future.wait([
        for (final u in units)
          _lrUnit(u.mainBookId, u.lrUnitNumber).catchError((Object e) {
            debugPrint(
              'HrOwnerService ZK ${u.mainBookId}/${u.lrUnitNumber}: $e',
            );
            return null;
          }),
      ]);
      return ownersFrom(parcelInfo, answers);
    } catch (e) {
      debugPrint('HrOwnerService.lookup($sifko, $parcela) failed: $e');
      return miss;
    }
  }

  /// The owners of a parcel from its `/cad/parcel-info` response and the
  /// `/lr/lr-unit` answers for the ZK units it links to (null where a unit
  /// could not be read). ZK owners come first, the cadastre holders when
  /// no unit gave any. The answer is complete, and may be cached, only when
  /// every unit was read: with one missing, the ZK may name owners the
  /// cadastre or the other units leave out, so it is asked again next time.
  @visibleForTesting
  static HrOwnerAnswer ownersFrom(
    Map<String, dynamic> parcelInfo,
    List<Map<String, dynamic>?> lrAnswers,
  ) {
    final read = [for (final a in lrAnswers) ?a];
    final complete = read.length == lrAnswers.length;
    final info =
        (read.isEmpty ? null : parseLrUnits(read, parcelInfo)) ??
        parseParcelInfo(parcelInfo);
    return (info: info, complete: complete);
  }

  /// The ZK unit (zemljišnoknjižni uložak) as the portal's "Pregled ZK
  /// uloška" page asks for it. The answer is a list holding the unit.
  Future<Map<String, dynamic>?> _lrUnit(int mainBookId, String number) async {
    final uri = Uri.parse('$_base/lr/lr-unit').replace(
      queryParameters: {
        'mainBookId': '$mainBookId',
        'lrUnitNumber': number,
        'historicalOverview': 'false',
      },
    );
    final res = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is Map<String, dynamic>) return body;
    if (body is List && body.isNotEmpty && body.first is Map<String, dynamic>) {
      return body.first as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _parcelInfo(String parcelId) async {
    final res = await _client
        .get(
          Uri.parse('$_base/cad/parcel-info?parcelId=$parcelId'),
          headers: _headers,
        )
        .timeout(_timeout);
    if (res.statusCode != 200) return null;
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// DGU parcel id for a KO + parcel number. The search matches by prefix,
  /// so pick the exact number.
  Future<String?> _parcelId(int sifko, String parcela) async {
    final uri = Uri.parse('$_base/search-cad-parcels/parcel-numbers').replace(
      queryParameters: {'search': parcela, 'municipalityRegNum': '$sifko'},
    );
    final res = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final rows = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    for (final r in rows.cast<Map<String, dynamic>>()) {
      if ((r['value1'] ?? '').toString().trim() == parcela) {
        return r['key1']?.toString();
      }
    }
    return null;
  }

  /// The distinct ZK units a `/cad/parcel-info` response links to, from
  /// `lrUnitsFromParcelLinks` and each `parcelLinks[].lrUnit`. Units not
  /// active (status other than 0) are left out.
  @visibleForTesting
  static List<({int mainBookId, String lrUnitNumber})> lrUnitsOf(
    Map<String, dynamic> parcelInfo,
  ) {
    final units = <({int mainBookId, String lrUnitNumber})>[];
    void add(Object? raw) {
      if (raw is! Map<String, dynamic>) return;
      final status = raw['status']?.toString();
      if (status != null && status != '0') return;
      final book = int.tryParse('${raw['mainBookId']}');
      final number = raw['lrUnitNumber']?.toString().trim() ?? '';
      if (book == null || number.isEmpty) return;
      final unit = (mainBookId: book, lrUnitNumber: number);
      if (!units.contains(unit)) units.add(unit);
    }

    add(parcelInfo['lrUnit']);
    for (final u in parcelInfo['lrUnitsFromParcelLinks'] as List? ?? []) {
      add(u);
    }
    for (final link in parcelInfo['parcelLinks'] as List? ?? []) {
      if (link is Map<String, dynamic>) add(link['lrUnit']);
    }
    return units;
  }

  static final _shareRe = RegExp(r'dio(?:\s+etaže)?:\s*(\d+(?:,\d+)?/\d+)');

  /// The share in a ZK share description: "1. Vlasnički dio: 1/2" → "1/2",
  /// "2.3. Suvlasnički dio etaže: 1/2" → "1/2". Null when the share has no
  /// fraction ("Suvlasnički dio s neodređenim omjerom ...").
  @visibleForTesting
  static String? shareOf(String? description) =>
      _shareRe.firstMatch(description ?? '')?.group(1);

  /// Owner info from ZK units (`/lr/lr-unit` answers): every owner on sheet B
  /// (vlasnički list) with their share. Deleted shares (status other than 0)
  /// are skipped; owners of a sub-share get the sub-share's fraction. An
  /// owner the ZK gives no address for takes the address of the cadastre
  /// holder of the same name in [parcelInfo]. Null when no unit has owners.
  @visibleForTesting
  static OwnerInfo? parseLrUnits(
    List<Map<String, dynamic>> units,
    Map<String, dynamic> parcelInfo,
  ) {
    final cadastre = parseParcelInfo(parcelInfo);
    final cadastreAddress = <String, String>{
      for (final h in cadastre?.holders ?? const <OwnerHolder>[])
        if (h.address != null) KoLocator.fold(h.name): h.address!,
    };
    final names = <String>[];
    final shares = <String, List<String>>{};
    final addresses = <String, String?>{};
    var unitHasOwners = false;

    void walk(List<dynamic>? list, String? parentShare) {
      for (final raw in list ?? const []) {
        if (raw is! Map<String, dynamic>) continue;
        final status = raw['status'];
        // Entries (zabilježbe) under a share carry no status and no owners.
        if (status != null && status.toString() != '0') continue;
        final share = shareOf(raw['description'] as String?) ?? parentShare;
        for (final o in raw['lrOwners'] as List? ?? const []) {
          if (o is! Map<String, dynamic>) continue;
          final name = (o['name'] as String?)?.trim();
          if (name == null || name.isEmpty) continue;
          unitHasOwners = true;
          if (!names.contains(name)) {
            names.add(name);
            shares[name] = [];
            addresses[name] =
                _cleanAddress(o['address'] as String?) ??
                cadastreAddress[KoLocator.fold(name)];
          }
          if (share != null && !shares[name]!.contains(share)) {
            shares[name]!.add(share);
          }
        }
        walk(raw['subSharesAndEntries'] as List?, share);
      }
    }

    final sources = <OwnerSource>[];
    for (final unit in units) {
      final sheet = unit['ownershipSheetB'];
      if (sheet is! Map<String, dynamic>) continue;
      unitHasOwners = false;
      walk(sheet['lrUnitShares'] as List?, null);
      if (!unitHasOwners) continue;
      final book = int.tryParse('${unit['mainBookId']}');
      final number = unit['lrUnitNumber']?.toString().trim();
      final place = (unit['mainBookName'] as String?)?.trim();
      sources.add(
        OwnerSource(
          OwnerSourceKind.landRegistry,
          lrUnitNumber: number,
          place: (place == null || place.isEmpty) ? null : place,
          url: book == null || number == null || number.isEmpty
              ? null
              : lrUnitUrl(book, number),
        ),
      );
    }
    if (names.isEmpty) return null;
    final holders = [
      for (final n in names)
        OwnerHolder(
          n,
          share: shares[n]!.isEmpty ? null : shares[n]!.join(' + '),
          address: addresses[n],
        ),
    ];
    final ko = (parcelInfo['cadMunicipalityName'] as String?)?.trim();
    return OwnerInfo(
      owners: names,
      holders: holders,
      address: holders.map((h) => h.address).nonNulls.firstOrNull,
      koName: (ko == null || ko.isEmpty) ? null : ko,
      sources: sources,
    );
  }

  static String? _cleanAddress(String? raw) {
    final a = raw?.trim();
    if (a == null || a.isEmpty || a.toUpperCase() == _unknownAddress) {
      return null;
    }
    return a;
  }

  /// Owner info from a `/cad/parcel-info` response: every holder on the
  /// parcel's possession sheets, the first known address and the KO name.
  @visibleForTesting
  static OwnerInfo? parseParcelInfo(Map<String, dynamic> json) {
    final owners = <String>[];
    final holders = <OwnerHolder>[];
    String? address;
    for (final sheet in (json['possessionSheets'] as List<dynamic>? ?? [])) {
      final possessors =
          (sheet as Map<String, dynamic>)['possessors'] as List<dynamic>? ?? [];
      for (final p in possessors.cast<Map<String, dynamic>>()) {
        final name = (p['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        if (owners.contains(name)) continue;
        final addr = _cleanAddress(p['address'] as String?);
        final share = (p['ownership'] as String?)?.trim();
        owners.add(name);
        holders.add(
          OwnerHolder(
            name,
            share: (share == null || share.isEmpty) ? null : share,
            address: addr,
          ),
        );
        address ??= addr;
      }
    }
    if (owners.isEmpty) return null;
    final ko = (json['cadMunicipalityName'] as String?)?.trim();
    final koName = (ko == null || ko.isEmpty) ? null : ko;
    return OwnerInfo(
      owners: owners,
      holders: holders,
      address: address,
      koName: koName,
      sources: [
        OwnerSource(
          OwnerSourceKind.cadastre,
          place: koName,
          url: parcelMapUrl(json),
        ),
      ],
    );
  }
}

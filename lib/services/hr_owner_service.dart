import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'cache_settings.dart';
import 'owner_lookup_service.dart';

/// Holders (posjednici) of a Croatian parcel, fetched from the public DGU
/// cadastre (oss.uredjenazemlja.hr). Every answer is kept on disk with no
/// expiry, so a parcel is asked about once; misses are not cached.
class HrOwnerService {
  HrOwnerService._();
  static final HrOwnerService instance = HrOwnerService._();

  static const _base = 'https://oss.uredjenazemlja.hr/oss/public';
  static const _timeout = Duration(seconds: 15);

  /// The register's placeholder address for a holder whose residence is
  /// unknown; not worth showing.
  static const _unknownAddress = 'NEPOZNATO BORAVIŠTE';

  static const _cacheFile = 'hr_owners_cache.json';

  /// Lookups in flight or answered this session.
  final _cache = <String, Future<OwnerInfo?>>{};

  /// Answers kept on disk, keyed like [_cache]; loaded on first use.
  Map<String, dynamic>? _stored;
  Future<Map<String, dynamic>>? _loading;

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
    final future = _cachedOrFetch(key, sifko, parcela.trim(), parcelId);
    _cache[key] = future;
    // Forget misses (_fetch never throws) so the next look retries.
    future.then((v) {
      if (v == null) _cache.remove(key);
    });
    return future;
  }

  Future<OwnerInfo?> _cachedOrFetch(
    String key,
    int sifko,
    String parcela,
    String? parcelId,
  ) async {
    // The HTTP cache switch in About covers this cache too.
    final useCache = CacheSettings.instance.httpEnabled;
    final stored = await _load();
    final hit = useCache ? stored[key] : null;
    if (hit is Map<String, dynamic>) return _fromJson(hit);
    final info = await _fetch(sifko, parcela, parcelId);
    if (info != null && useCache) {
      stored[key] = _toJson(info);
      unawaited(_save(stored));
    }
    return info;
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
        debugPrint('HrOwnerService cache read failed: $e');
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
      debugPrint('HrOwnerService cache write failed: $e');
    }
  }

  static Map<String, dynamic> _toJson(OwnerInfo info) => {
        'koName': info.koName,
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
      for (final h in (j['holders'] as List<dynamic>).cast<Map<String, dynamic>>())
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
    );
  }

  Future<OwnerInfo?> _fetch(int sifko, String parcela, String? parcelId) async {
    try {
      if (parcelId != null && int.tryParse(parcelId) != null) {
        final json = await _parcelInfo(parcelId);
        // Trust a passed-in id only when it really is this parcel.
        if (json != null &&
            json['cadMunicipalityRegNum']?.toString() == '$sifko' &&
            json['parcelNumber']?.toString().trim() == parcela) {
          return parseParcelInfo(json);
        }
      }
      final id = await _parcelId(sifko, parcela);
      if (id == null) return null;
      final json = await _parcelInfo(id);
      return json == null ? null : parseParcelInfo(json);
    } catch (e) {
      debugPrint('HrOwnerService.lookup($sifko, $parcela) failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _parcelInfo(String parcelId) async {
    final res = await http
        .get(Uri.parse('$_base/cad/parcel-info?parcelId=$parcelId'))
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
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return null;
    final rows = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    for (final r in rows.cast<Map<String, dynamic>>()) {
      if ((r['value1'] ?? '').toString().trim() == parcela) {
        return r['key1']?.toString();
      }
    }
    return null;
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
        final rawAddr = (p['address'] as String?)?.trim();
        final addr = (rawAddr == null ||
                rawAddr.isEmpty ||
                rawAddr.toUpperCase() == _unknownAddress)
            ? null
            : rawAddr;
        final share = (p['ownership'] as String?)?.trim();
        owners.add(name);
        holders.add(OwnerHolder(
          name,
          share: (share == null || share.isEmpty) ? null : share,
          address: addr,
        ));
        address ??= addr;
      }
    }
    if (owners.isEmpty) return null;
    final ko = (json['cadMunicipalityName'] as String?)?.trim();
    return OwnerInfo(
      owners: owners,
      holders: holders,
      address: address,
      koName: (ko == null || ko.isEmpty) ? null : ko,
    );
  }
}

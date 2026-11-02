import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';
import '../utils/formats.dart';
import 'map_location.dart';
import 'parcel.dart';

/// One tree in a sečnja share.
class SecnjaPoint {
  String name;
  double lat;
  double lng;
  String? species;

  SecnjaPoint({
    required this.name,
    required this.lat,
    required this.lng,
    this.species,
  });

  LatLng get position => LatLng(lat, lng);

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        if (species != null) 'species': species,
      };

  factory SecnjaPoint.fromJson(Map<String, dynamic> json) => SecnjaPoint(
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        species: json['species'] as String?,
      );
}

/// The data that a sečnja share link carries: one parcel and its marked
/// trees. The worker stores it as JSON (version 1).
class SecnjaSharePayload {
  String parcelNumber;
  int? koNumber;
  String? koName;
  String? owner;
  double? areaHa;
  List<LatLng> polygon;
  List<SecnjaPoint> points;
  DateTime createdAt;

  /// Set by the server. Null before the first upload.
  DateTime? expiresAt;

  SecnjaSharePayload({
    required this.parcelNumber,
    this.koNumber,
    this.koName,
    this.owner,
    this.areaHa,
    this.polygon = const [],
    this.points = const [],
    required this.createdAt,
    this.expiresAt,
  });

  /// Builds the payload for [parcel] and its sečnja [marks].
  /// A mark gets a species when its name starts with one from [species].
  factory SecnjaSharePayload.fromParcel(
    Parcel parcel,
    List<MapLocation> marks, {
    String? koName,
    required List<String> species,
    DateTime? now,
  }) {
    final owner = parcel.owner?.trim();
    final area = parcel.areaM2;
    return SecnjaSharePayload(
      parcelNumber: parcel.parcelNumber ?? parcel.name,
      koNumber: parcel.cadastralMunicipality,
      koName: (koName == null || koName.isEmpty) ? null : koName,
      owner: (owner == null || owner.isEmpty) ? null : owner,
      areaHa: area > 0 ? area / 10000 : null,
      polygon: parcel.polygon,
      points: [
        for (final m in marks)
          SecnjaPoint(
            name: m.name,
            lat: m.latitude,
            lng: m.longitude,
            species: _speciesOf(m.name, species),
          ),
      ],
      createdAt: (now ?? DateTime.now()).toUtc(),
    );
  }

  static String? _speciesOf(String name, List<String> species) {
    final first = name.trim().split(RegExp(r'\s+')).first.toLowerCase();
    for (final s in species) {
      if (s.toLowerCase() == first) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'parcel': {
          'number': parcelNumber,
          if (koNumber != null) 'koNumber': koNumber,
          if (koName != null) 'koName': koName,
          if (owner != null) 'owner': owner,
          if (areaHa != null) 'areaHa': areaHa,
          'polygon': [
            for (final p in polygon) [p.latitude, p.longitude],
          ],
        },
        'points': [for (final p in points) p.toJson()],
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory SecnjaSharePayload.fromJson(Map<String, dynamic> json) {
    final parcel = json['parcel'] as Map<String, dynamic>;
    final expires = json['expiresAt'] as String?;
    return SecnjaSharePayload(
      parcelNumber: parcel['number'] as String,
      koNumber: (parcel['koNumber'] as num?)?.toInt(),
      koName: parcel['koName'] as String?,
      owner: parcel['owner'] as String?,
      areaHa: (parcel['areaHa'] as num?)?.toDouble(),
      polygon: [
        for (final p in (parcel['polygon'] as List? ?? const []))
          LatLng(
            ((p as List)[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          ),
      ],
      points: [
        for (final p in (json['points'] as List))
          SecnjaPoint.fromJson(p as Map<String, dynamic>),
      ],
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: expires == null ? null : DateTime.parse(expires),
    );
  }

  /// SHA-256 of the content, without the dates. Two payloads with the same
  /// parcel and trees have the same hash.
  String get contentHash {
    final json = toJson()..remove('createdAt');
    return sha256.convert(utf8.encode(jsonEncode(_sorted(json)))).toString();
  }

  static Object? _sorted(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _sorted(value[k])};
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }
}

/// The text that the owner sends to the logger with the share [link].
String shareMessage(
  SecnjaSharePayload payload,
  Uri link,
  AppLocalizations l10n,
) {
  final ko = payload.koName ?? payload.koNumber?.toString() ?? '';
  final count = l10n.secnjaShareCount(payload.points.length);
  final area = payload.areaHa;
  return [
    l10n.secnjaShareHeadline(payload.parcelNumber, ko),
    area == null ? count : '$count · ${Fmt.num(area, 2)} ha',
    if (payload.owner != null) l10n.secnjaShareOwner(payload.owner!),
    link.toString(),
    if (payload.expiresAt != null)
      l10n.secnjaShareValidUntil(Fmt.date(payload.expiresAt!.toLocal())),
  ].join('\n');
}

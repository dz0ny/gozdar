import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/l10n/l10n.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/models/secnja_share.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';

Parcel parcel({String? owner = 'Janez Novak', bool withPolygon = true}) => Parcel(
      name: 'Parcela 1234/5',
      cadastralMunicipality: 1234,
      parcelNumber: '1234/5',
      owner: owner,
      polygon: withPolygon
          ? const [
              LatLng(46.0, 14.0),
              LatLng(46.01, 14.0),
              LatLng(46.01, 14.01),
              LatLng(46.0, 14.01),
            ]
          : null,
    );

List<MapLocation> marks() => [
      MapLocation(name: 'Smreka 1', latitude: 46.005, longitude: 14.005, type: LocationType.secnja),
      MapLocation(name: 'Drevo 2', latitude: 46.006, longitude: 14.006, type: LocationType.secnja),
    ];

SecnjaSharePayload build({String? owner = 'Janez Novak', List<MapLocation>? m, DateTime? now}) =>
    SecnjaSharePayload.fromParcel(
      parcel(owner: owner),
      m ?? marks(),
      koName: 'Dolenja vas',
      species: const ['Smreka', 'Bukev'],
      now: now ?? DateTime.utc(2026, 11, 2, 10),
    );

void main() {
  final l10n = lookupAppLocalizations(const Locale('sl'));

  setUpAll(() => initializeDateFormatting());

  test('toJson matches the spec schema', () {
    final json = build().toJson();
    expect(json['v'], 1);
    expect(json['parcel']['number'], '1234/5');
    expect(json['parcel']['koNumber'], 1234);
    expect(json['parcel']['koName'], 'Dolenja vas');
    expect(json['parcel']['owner'], 'Janez Novak');
    expect(json['parcel']['areaHa'], greaterThan(0));
    expect(json['parcel']['polygon'], hasLength(4));
    expect(json['parcel']['polygon'][0], [46.0, 14.0]);
    expect(json['points'][0], {'name': 'Smreka 1', 'lat': 46.005, 'lng': 14.005, 'species': 'Smreka'});
    expect((json['points'][1] as Map).containsKey('species'), isFalse);
    expect(json['createdAt'], '2026-11-02T10:00:00.000Z');
  });

  test('fromJson(toJson(x)) round-trips', () {
    final a = build();
    final b = SecnjaSharePayload.fromJson(a.toJson());
    expect(b.toJson(), a.toJson());
  });

  test('fromJson reads expiresAt from the server', () {
    final json = build().toJson()..['expiresAt'] = '2026-12-02T10:00:00.000Z';
    expect(SecnjaSharePayload.fromJson(json).expiresAt, DateTime.utc(2026, 12, 2, 10));
  });

  test('blank owner and zero area are omitted', () {
    final p = SecnjaSharePayload.fromParcel(
      parcel(owner: '  ', withPolygon: false),
      marks(),
      species: const [],
    );
    final json = p.toJson();
    expect((json['parcel'] as Map).containsKey('owner'), isFalse);
    expect((json['parcel'] as Map).containsKey('areaHa'), isFalse);
    expect((json['parcel'] as Map).containsKey('koName'), isFalse);
  });

  test('contentHash ignores createdAt', () {
    expect(
      build(now: DateTime.utc(2026, 1, 1)).contentHash,
      build(now: DateTime.utc(2026, 6, 1)).contentHash,
    );
  });

  test('contentHash is stable for č/š/ž names and reordered keys', () {
    final a = SecnjaSharePayload.fromJson({
      'v': 1,
      'parcel': {'number': '7/1', 'polygon': []},
      'points': [
        {'name': 'Bukev čšž 3', 'lat': 46.1, 'lng': 14.2},
      ],
      'createdAt': '2026-11-02T10:00:00.000Z',
    });
    final b = SecnjaSharePayload.fromJson({
      'createdAt': '2026-11-03T10:00:00.000Z',
      'points': [
        {'lng': 14.2, 'lat': 46.1, 'name': 'Bukev čšž 3'},
      ],
      'parcel': {'polygon': [], 'number': '7/1'},
      'v': 1,
    });
    expect(a.contentHash, b.contentHash);
  });

  test('contentHash changes when a mark is renamed or removed', () {
    final base = build().contentHash;
    final renamed = marks()..[1].name = 'Bukev 2';
    expect(build(m: renamed).contentHash, isNot(base));
    expect(build(m: marks().sublist(0, 1)).contentHash, isNot(base));
  });

  test('shareTitle names the parcel and k.o.', () {
    expect(shareTitle(build(), l10n), '🪓 Sečnja — parcela 1234/5, k.o. Dolenja vas');
  });

  test('shareTitle with koName null uses the k.o. number', () {
    final p = SecnjaSharePayload.fromParcel(parcel(), marks(), species: const []);
    expect(shareTitle(p, l10n), '🪓 Sečnja — parcela 1234/5, k.o. 1234');
  });
}

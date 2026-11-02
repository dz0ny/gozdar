import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/models/map_location.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/models/secnja_share.dart';
import 'package:gozdar/services/database_service.dart';
import 'package:gozdar/services/secnja_share_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

final base = Uri.parse('https://gozdar.test');

SecnjaSharePayload payload({String name = 'Smreka 1'}) => SecnjaSharePayload(
      parcelNumber: '1234/5',
      polygon: const [LatLng(46, 14), LatLng(46.01, 14), LatLng(46.01, 14.01)],
      points: [SecnjaPoint(name: name, lat: 46.005, lng: 14.005)],
      createdAt: DateTime.utc(2026, 11, 2),
    );

String serverJson({String name = 'Smreka 1', String expires = '2026-12-02T10:00:00.000Z'}) =>
    jsonEncode(payload(name: name).toJson()..['expiresAt'] = expires);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final dbService = DatabaseService();
  late List<http.Request> requests;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dbService.setDatabaseForTesting(db);
    requests = [];
  });

  tearDown(() => dbService.resetForTesting());

  SecnjaShareService serviceWith(Future<http.Response> Function(http.Request) handler) =>
      SecnjaShareService(
        client: MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
        db: dbService,
        base: base,
      );

  Future<Parcel> savedParcel() async {
    final id = await dbService.insertParcel(Parcel(name: 'A', parcelNumber: '1234/5'));
    return (await dbService.getParcel(id))!;
  }

  test('linkFor builds the /o/ link', () {
    expect(serviceWith((_) async => http.Response('', 500)).linkFor('abc123').toString(),
        'https://gozdar.test/o/abc123');
  });

  test('first share POSTs and stores id, token, hash', () async {
    final service = serviceWith((r) async => http.Response(
          jsonEncode({'id': 'abc123', 'editToken': 'tok', 'expiresAt': '2026-12-02T10:00:00.000Z'}),
          201,
        ));
    final p = payload();
    final result = await service.share(await savedParcel(), p);

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/s');
    expect(jsonDecode(requests.single.body)['points'][0]['name'], 'Smreka 1');
    expect(result.link.toString(), 'https://gozdar.test/o/abc123');
    expect(result.expiresAt, DateTime.utc(2026, 12, 2, 10));
    final saved = (await dbService.getAllParcels()).single;
    expect(saved.shareId, 'abc123');
    expect(saved.shareEditToken, 'tok');
    expect(saved.shareHash, p.contentHash);
  });

  test('second share PUTs with Bearer token to the same id', () async {
    final parcel = await savedParcel();
    await dbService.saveParcelShare(parcel.id,
        shareId: 'abc123', editToken: 'tok', hash: 'old', sharedAt: DateTime(2026), expiresAt: DateTime(2026, 2));
    final service = serviceWith(
        (r) async => http.Response(jsonEncode({'expiresAt': '2026-12-02T10:00:00.000Z'}), 200));

    final result = await service.share((await dbService.getParcel(parcel.id))!, payload(name: 'Bukev 1'));

    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/api/s/abc123');
    expect(requests.single.headers['Authorization'], 'Bearer tok');
    expect(result.link.path, '/o/abc123');
    expect((await dbService.getParcel(parcel.id))!.shareHash, payload(name: 'Bukev 1').contentHash);
  });

  test('PUT 404 falls back to POST and stores the new id', () async {
    final parcel = await savedParcel();
    await dbService.saveParcelShare(parcel.id,
        shareId: 'gone00', editToken: 'tok', hash: 'old', sharedAt: DateTime(2026), expiresAt: DateTime(2026, 2));
    final service = serviceWith((r) async => r.method == 'PUT'
        ? http.Response('{"error":"Not Found"}', 404)
        : http.Response(
            jsonEncode({'id': 'new111', 'editToken': 'tok2', 'expiresAt': '2026-12-02T10:00:00.000Z'}), 201));

    final result = await service.share((await dbService.getParcel(parcel.id))!, payload());

    expect(requests.map((r) => r.method), ['PUT', 'POST']);
    expect(result.link.path, '/o/new111');
    expect((await dbService.getParcel(parcel.id))!.shareEditToken, 'tok2');
  });

  test('server error throws ShareException and keeps local state', () async {
    final parcel = await savedParcel();
    final service = serviceWith((_) async => http.Response('boom', 500));
    await expectLater(service.share(parcel, payload()), throwsA(isA<ShareException>()));
    expect((await dbService.getParcel(parcel.id))!.isShared, isFalse);
  });

  test('network error throws ShareException', () async {
    final parcel = await savedParcel();
    final service = serviceWith((_) async => throw const SocketException('offline'));
    await expectLater(service.share(parcel, payload()), throwsA(isA<ShareException>()));
  });

  test('revoke DELETEs and clears local state; 404 is fine', () async {
    final parcel = await savedParcel();
    await dbService.saveParcelShare(parcel.id,
        shareId: 'abc123', editToken: 'tok', hash: 'h', sharedAt: DateTime(2026), expiresAt: DateTime(2026, 2));
    final service = serviceWith((_) async => http.Response('', 404));

    await service.revoke((await dbService.getParcel(parcel.id))!);

    expect(requests.single.method, 'DELETE');
    expect(requests.single.headers['Authorization'], 'Bearer tok');
    expect((await dbService.getParcel(parcel.id))!.isShared, isFalse);
  });

  test('revokeQuietly DELETEs a shared parcel and never throws', () async {
    final parcel = await savedParcel();
    await dbService.saveParcelShare(parcel.id,
        shareId: 'abc123', editToken: 'tok', hash: 'h', sharedAt: DateTime(2026), expiresAt: DateTime(2026, 2));
    final shared = (await dbService.getParcel(parcel.id))!;

    await serviceWith((_) async => http.Response('', 204)).revokeQuietly(shared);
    expect(requests.single.method, 'DELETE');

    await serviceWith((_) async => throw const SocketException('offline')).revokeQuietly(shared);
  });

  test('revokeQuietly does nothing for a parcel that is not shared', () async {
    await serviceWith((_) async => http.Response('', 204)).revokeQuietly(await savedParcel());
    expect(requests, isEmpty);
  });

  // ---- Receiving imports the parcel and its trees ----

  String sharedJson({
    String number = '1234/5',
    int? ko = 1722,
    List<Map<String, Object>> points = const [
      {'name': 'Smreka 1', 'lat': 46.005, 'lng': 14.005, 'species': 'Smreka'},
      {'name': 'Drevo 2', 'lat': 46.006, 'lng': 14.006},
    ],
  }) =>
      jsonEncode({
        'v': 1,
        'parcel': {
          'number': number,
          'koNumber': ?ko,
          'koName': 'Testna vas',
          'owner': 'Janez N.',
          'polygon': [
            [46.0, 14.0],
            [46.01, 14.0],
            [46.01, 14.01],
            [46.0, 14.01],
          ],
        },
        'points': points,
        'createdAt': '2026-11-02T10:00:00.000Z',
        'expiresAt': '2026-12-02T10:00:00.000Z',
      });

  SecnjaShareService serving(String Function() body) =>
      serviceWith((_) async => http.Response.bytes(utf8.encode(body()), 200));

  Future<List<String>> markNames(int parcelId) async =>
      (await dbService.getSecnjaByParcel(parcelId)).map((m) => m.name).toList();

  test('receive creates the parcel with its trees', () async {
    final result = await serving(sharedJson).receive('abc123');

    expect(result.outcome, ReceiveOutcome.imported);
    final parcel = (await dbService.getAllParcels()).single;
    expect(result.parcelId, parcel.id);
    expect(parcel.cadastralMunicipality, 1722);
    expect(parcel.parcelNumber, '1234/5');
    expect(parcel.name, 'Testna vas - 1234/5');
    expect(parcel.owner, 'Janez N.');
    expect(parcel.polygon, hasLength(4));
    expect(parcel.isShared, isFalse);
    expect(await markNames(parcel.id), ['Smreka 1', 'Drevo 2']);
  });

  test('receive adds the trees to a parcel the logger already has', () async {
    final id = await dbService.insertParcel(
      Parcel(name: 'Moja', cadastralMunicipality: 1722, parcelNumber: '1234/5'),
    );
    await serving(sharedJson).receive('abc123');

    expect(await dbService.getAllParcels(), hasLength(1));
    expect((await dbService.getParcel(id))!.name, 'Moja');
    expect(await markNames(id), ['Smreka 1', 'Drevo 2']);
  });

  test('an updated link replaces its own trees and keeps the logger\'s', () async {
    var points = <Map<String, Object>>[
      {'name': 'Smreka 1', 'lat': 46.005, 'lng': 14.005},
      {'name': 'Drevo 2', 'lat': 46.006, 'lng': 14.006},
    ];
    final service = serving(() => sharedJson(points: points));
    final first = await service.receive('abc123');
    await dbService.insertLocation(MapLocation(
      name: 'Moje 1', latitude: 46.002, longitude: 14.002, type: LocationType.secnja,
    ));

    points = [
      {'name': 'Smreka 1', 'lat': 46.005, 'lng': 14.005},
      {'name': 'Bukev 3', 'lat': 46.007, 'lng': 14.007},
    ];
    await service.receive('abc123');

    expect(
      (await markNames(first.parcelId!))..sort(),
      ['Bukev 3', 'Moje 1', 'Smreka 1'],
    );
  });

  test('trees already marked at the same spot are not added twice', () async {
    await serving(sharedJson).receive('first1');
    final parcelId = (await dbService.getAllParcels()).single.id;
    // The same trees arrive again through a forwarded link.
    await serving(sharedJson).receive('second');
    expect(await markNames(parcelId), ['Smreka 1', 'Drevo 2']);
  });

  test('opening your own link changes nothing', () async {
    final id = await dbService.insertParcel(
      Parcel(name: 'Moja', cadastralMunicipality: 1722, parcelNumber: '1234/5'),
    );
    await dbService.saveParcelShare(id,
        shareId: 'mine00', editToken: 't', hash: 'h', sharedAt: DateTime(2026), expiresAt: DateTime(2026, 12));
    final result = await serving(sharedJson).receive('mine00');
    expect(result.outcome, ReceiveOutcome.imported);
    expect(result.parcelId, id);
    expect(await markNames(id), isEmpty);
  });

  test('a parcel without a k.o. is matched by name', () async {
    final id = await dbService.insertParcel(Parcel(name: 'Za hišo'));
    await serving(() => sharedJson(number: 'Za hišo', ko: null)).receive('abc123');
    expect(await dbService.getAllParcels(), hasLength(1));
    expect(await markNames(id), hasLength(2));
  });

  test('receive 404 returns expired and stores nothing', () async {
    final result = await serviceWith((_) async => http.Response('', 404)).receive('abc123');
    expect(result.outcome, ReceiveOutcome.expired);
    expect(await dbService.getAllParcels(), isEmpty);
  });

  test('receive on SocketException returns offline and stores nothing', () async {
    final result = await serviceWith((_) async => throw const SocketException('x')).receive('abc');
    expect(result.outcome, ReceiveOutcome.offline);
    expect(await dbService.getAllParcels(), isEmpty);
  });

  test('receive of an unreadable share returns invalid and stores nothing', () async {
    for (final body in ['<html>wifi login</html>', '{"parcel":null,"points":[]}', '{"v":2}']) {
      final service = serviceWith((_) async => http.Response(body, 200));
      expect((await service.receive('bad')).outcome, ReceiveOutcome.invalid);
    }
    expect(await dbService.getAllParcels(), isEmpty);
  });
}

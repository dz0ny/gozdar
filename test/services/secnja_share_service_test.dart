import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/db/app_database.dart';
import 'package:gozdar/models/parcel.dart';
import 'package:gozdar/models/received_share.dart';
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

  test('linkFor builds the /s/ link', () {
    expect(serviceWith((_) async => http.Response('', 500)).linkFor('abc123').toString(),
        'https://gozdar.test/s/abc123');
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
    expect(result.link.toString(), 'https://gozdar.test/s/abc123');
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
    expect(result.link.path, '/s/abc123');
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
    expect(result.link.path, '/s/new111');
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

  test('receive imports; receiving again replaces payload, one row', () async {
    var name = 'Smreka 1';
    final service = serviceWith((_) async => http.Response.bytes(utf8.encode(serverJson(name: name)), 200));

    expect(await service.receive('abc123'), ReceiveOutcome.imported);
    name = 'Bukev 9';
    expect(await service.receive('abc123'), ReceiveOutcome.imported);

    final all = await dbService.getReceivedShares();
    expect(all, hasLength(1));
    expect(all.single.payload.points.single.name, 'Bukev 9');
    expect(all.single.expiresAt.toUtc(), DateTime.utc(2026, 12, 2, 10));
    expect(service.lastReceived?.parcelNumber, '1234/5');
  });

  test('receive 404 deletes the local row and returns expired', () async {
    await dbService.upsertReceivedShare(ReceivedShare(
      shareId: 'abc123',
      payloadJson: serverJson(),
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
    ));
    final service = serviceWith((_) async => http.Response('', 404));
    expect(await service.receive('abc123'), ReceiveOutcome.expired);
    expect(await dbService.getReceivedShares(), isEmpty);
  });

  test('receive on SocketException returns offline and stores nothing', () async {
    final service = serviceWith((_) async => throw const SocketException('offline'));
    expect(await service.receive('abc123'), ReceiveOutcome.offline);
    expect(await dbService.getReceivedShares(), isEmpty);
  });

  test('refreshReceived purges expired rows even when every request fails', () async {
    await dbService.upsertReceivedShare(ReceivedShare(
      shareId: 'old',
      payloadJson: serverJson(),
      fetchedAt: DateTime(2026),
      expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    ));
    await dbService.upsertReceivedShare(ReceivedShare(
      shareId: 'live',
      payloadJson: serverJson(),
      fetchedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
    ));
    final service = serviceWith((_) async => throw const SocketException('offline'));

    await service.refreshReceived();

    expect(requests.map((r) => r.url.path), ['/api/s/live']);
    expect(await db.select(db.receivedShares).get(), hasLength(1));
  });
}

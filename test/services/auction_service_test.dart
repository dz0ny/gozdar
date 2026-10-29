import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/auction_service.dart';

Map<String, dynamic> _row({
  String status = 'waiting_start',
  Object? ko = '2301',
  Object? parcel = '868',
}) =>
    {
      'id': 'b2c60bcc-6511-4d61-aba6-c81c9647f8c8',
      'publicationId': '20260916-0104-007',
      'status': status,
      'saleStartAt': '2027-11-24T12:30:01Z',
      'cadastralMunicipalityCode': ko,
      'cadastralMunicipalityName': 'RAVNICA',
      'parcelNumber': parcel,
      'area': '209',
      'startingPrice': '160',
      'estimatedPrice': '160',
      'shareInTheBasicLegalPosition': '1/1',
      'courtRelation': {'valueContent': 'Okrožno sodišče v Novi Gorici'},
      'subjectTypeRelation': {'valueContent': 'Zemljišča'},
    };

void main() {
  group('Auction.fromRow', () {
    test('reads a land auction', () {
      final a = Auction.fromRow(_row())!;
      expect(a.sifko, 2301);
      expect(a.parcela, '868');
      expect(a.koName, 'RAVNICA');
      expect(a.area, 209);
      expect(a.startingPrice, 160);
      expect(a.share, '1/1');
      expect(a.court, 'Okrožno sodišče v Novi Gorici');
      expect(a.kind, 'Zemljišča');
      expect(a.saleStartAt, DateTime.utc(2027, 11, 24, 12, 30, 1));
      expect(a.url, endsWith('/single/b2c60bcc-6511-4d61-aba6-c81c9647f8c8'));
      expect(a.key, '2301/868');
    });

    test('skips cancelled sales and rows without a parcel', () {
      expect(Auction.fromRow(_row(status: 'canceled')), isNull);
      expect(Auction.fromRow(_row(ko: null)), isNull);
      expect(Auction.fromRow(_row(parcel: '')), isNull);
    });

    test('survives a round trip through the cache', () {
      final a = Auction.fromRow(_row())!;
      final b = Auction.fromJson(a.toJson());
      expect(b.key, a.key);
      expect(b.startingPrice, a.startingPrice);
      expect(b.saleStartAt, a.saleStartAt);
    });
  });
}

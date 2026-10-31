import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/tile_download_service.dart';

void main() {
  test('tileUrl fills z/x/y the way the map requests them', () {
    expect(
      TileDownloadService.tileUrl('https://t.example/{z}/{x}/{y}.png', 15, 17800, 11600),
      'https://t.example/15/17800/11600.png',
    );
  });

  test('tileUrl is deterministic so peer sync and downloads share keys', () {
    const template = 'https://{s}.t.example/{z}/{x}/{y}.png';
    expect(
      TileDownloadService.tileUrl(template, 12, 4, 7),
      TileDownloadService.tileUrl(template, 12, 4, 7),
    );
  });

  test('tileUrl fills {bbox} for direct WMS layers', () {
    expect(
      TileDownloadService.tileUrl('https://w.example/wms?BBOX={bbox}', 1, 1, 1),
      'https://w.example/wms?BBOX=0.00,-20037508.34,20037508.34,0.00',
    );
  });
}

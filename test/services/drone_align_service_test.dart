import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/drone_align_service.dart';
import 'package:gozdar/services/drone_photo_service.dart';
import 'package:latlong2/latlong.dart';

const _r = 6378137.0;

/// Smooth ground texture with features of 3 to 12 metres.
double ground(double x, double y) {
  const k = [
    [0.55, 0.20, 0.3],
    [-0.30, 0.65, 1.1],
    [0.90, -0.45, 2.0],
    [0.15, 1.10, 0.7],
    [-1.20, -0.35, 2.7],
    [0.40, 0.40, 1.9],
  ];
  var v = 0.0;
  for (final c in k) {
    v += math.sin(c[0] * x + c[1] * y + c[2]);
  }
  return (v / (2 * k.length) + 0.5).clamp(0.0, 1.0);
}

Future<List<int>> photoPng(
  double cx,
  double cy,
  double headingDeg,
  double heightM,
) async {
  const w = 192, h = 144;
  final wm = heightM * 1.5, hm = wm * 0.75;
  final th = headingDeg * math.pi / 180;
  final pixels = Uint8List(w * h * 4);
  for (var py = 0; py < h; py++) {
    for (var px = 0; px < w; px++) {
      final right = ((px + 0.5) / w - 0.5) * wm;
      final up = (0.5 - (py + 0.5) / h) * hm;
      final gx = cx + right * math.cos(th) + up * math.sin(th);
      final gy = cy - right * math.sin(th) + up * math.cos(th);
      final v = (ground(gx, gy) * 255).round();
      final i = (py * w + px) * 4;
      pixels[i] = v;
      pixels[i + 1] = v;
      pixels[i + 2] = v;
      pixels[i + 3] = 255;
    }
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, done.complete);
  final image = await done.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('alignment pulls GPS-shifted photos back towards the truth',
      (tester) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('align_test');
      addTearDown(() => dir.delete(recursive: true));

      const origin = LatLng(46.0509, 14.5013);
      final cosLat = math.cos(origin.latitude * math.pi / 180);
      LatLng toLatLng(double x, double y) => LatLng(
        origin.latitude + y / _r * 180 / math.pi,
        origin.longitude + x / (_r * cosLat) * 180 / math.pi,
      );
      final polygon = [
        toLatLng(-60, -60),
        toLatLng(60, -60),
        toLatLng(60, 60),
        toLatLng(-60, 60),
      ];

      final rnd = math.Random(7);
      final photos = <DronePhoto>[];
      final truth = <(double, double)>[];
      final errors = <(double, double)>[];
      var n = 0;
      for (final ty in [-25.0, 0.0, 25.0]) {
        for (final tx in [-25.0, 0.0, 25.0]) {
          // Heading 30 degrees, so the rotation maths gets tested.
          final png = await photoPng(tx, ty, 30, 60);
          final file = File('${dir.path}/p${n++}.png')..writeAsBytesSync(png);
          final ex = (rnd.nextDouble() - 0.5) * 6;
          final ey = (rnd.nextDouble() - 0.5) * 6;
          truth.add((tx, ty));
          errors.add((ex, ey));
          photos.add(
            DronePhoto(
              file: file,
              position: toLatLng(tx + ex, ty + ey),
              relativeAltitudeM: 60,
              headingDeg: 30,
              pitchDeg: -90,
              width: 192,
              height: 144,
            ),
          );
        }
      }

      double meanError(List<DronePhoto> ps) {
        var sum = 0.0;
        for (var i = 0; i < ps.length; i++) {
          final x = (ps[i].position.longitude - origin.longitude) *
              math.pi / 180 * _r * cosLat;
          final y = (ps[i].position.latitude - origin.latitude) *
              math.pi / 180 * _r;
          sum += math.sqrt(
            math.pow(x - truth[i].$1, 2) + math.pow(y - truth[i].$2, 2),
          );
        }
        return sum / ps.length;
      }

      final before = meanError(photos);
      final (aligned, result) = await DroneAlignService.instance.align(
        photos,
        polygon,
      );
      final after = meanError(aligned);

      expect(result!.pairsUsed, greaterThan(8));
      expect(after, lessThan(before * 0.5));
      expect(after, lessThan(1.5));
    });
  });

  test('flat patches give no constraint and keep the GPS position', () {
    final flat = Float32List(40 * 40)..fillRange(0, 40 * 40, 0.5);
    AlignPatch p(int ox) => AlignPatch(gray: flat, w: 40, h: 40, ox: ox, oy: 0);
    final res = solveAlign(AlignJob([p(0), p(10)], 1, 5));
    expect(res.pairsUsed, 0);
    expect(res.dx, everyElement(0));
    expect(res.dy, everyElement(0));
  });
}

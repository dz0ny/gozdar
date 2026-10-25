import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/drone_mosaic_service.dart';
import 'package:gozdar/services/drone_photo_service.dart';
import 'package:latlong2/latlong.dart';

Future<File> solidPng(Directory dir, String name, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 64, 48),
    ui.Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(64, 48);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return File('${dir.path}/$name')..writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final square = [
    const LatLng(46.0500, 14.5000),
    const LatLng(46.0500, 14.5026),
    const LatLng(46.0518, 14.5026),
    const LatLng(46.0518, 14.5000),
  ];

  testWidgets('two photos land west and east of each other', (tester) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('mosaic_test');
      addTearDown(() => dir.delete(recursive: true));
      final red = await solidPng(dir, 'red.png', const ui.Color(0xFFFF0000));
      final blue = await solidPng(dir, 'blue.png', const ui.Color(0xFF0000FF));

      DronePhoto photo(File f, double lon) => DronePhoto(
        file: f,
        position: LatLng(46.0509, lon),
        relativeAltitudeM: 60,
        headingDeg: 0,
        pitchDeg: -90,
        width: 64,
        height: 48,
      );

      final img = await DroneMosaicService.instance.render(
        [photo(red, 14.5005), photo(blue, 14.5021)],
        square,
      );
      expect(img, isNotNull);

      final codec = await ui.instantiateImageCodec(img!.png);
      final decoded = (await codec.getNextFrame()).image;
      final bytes = (await decoded.toByteData())!;
      int rgba(int x, int y) {
        final i = (y * decoded.width + x) * 4;
        return (bytes.getUint8(i) << 16) |
            (bytes.getUint8(i + 1) << 8) |
            bytes.getUint8(i + 2);
      }

      final midY = decoded.height ~/ 2;
      expect(rgba(decoded.width ~/ 10, midY), 0xFF0000); // west is red
      expect(rgba(decoded.width * 9 ~/ 10, midY), 0x0000FF); // east is blue
    });
  });
}

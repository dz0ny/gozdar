import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:latlong2/latlong.dart';

import 'drone_photo_service.dart';
import 'parcel_pdf_service.dart' show GeoreferencedImage;

/// Georeferenced quick mosaic: where it is on the map and its image file.
class DroneMosaic {
  final File image;
  final LatLng southWest;
  final LatLng northEast;
  final int photoCount;
  final DateTime createdAt;

  const DroneMosaic({
    required this.image,
    required this.southWest,
    required this.northEast,
    required this.photoCount,
    required this.createdAt,
  });
}

/// Builds a rough mosaic by placing each nadir photo on a flat ground plane
/// using its GPS position, height and heading. No feature matching, so it is
/// a preview, not a surveyed orthophoto: expect metre-level offsets and
/// parallax on tall canopy.
class DroneMosaicService {
  DroneMosaicService._();
  static final DroneMosaicService instance = DroneMosaicService._();

  static const _r = 6378137.0;

  // Web Mercator helpers (metres).
  double _mx(double lon) => _r * lon * math.pi / 180;
  double _my(double lat) =>
      _r * math.log(math.tan(math.pi / 4 + lat * math.pi / 360));
  double _lon(double x) => x / _r * 180 / math.pi;
  double _lat(double y) =>
      (2 * math.atan(math.exp(y / _r)) - math.pi / 2) * 180 / math.pi;

  /// Renders [photos] into one PNG. Returns null when there is nothing to draw.
  Future<GeoreferencedImage?> render(
    List<DronePhoto> photos,
    List<LatLng> polygon, {
    PhotoFootprintOptions options = const PhotoFootprintOptions(),
    int maxPx = 3000,
    void Function(int done, int total)? onProgress,
  }) async {
    if (photos.isEmpty || polygon.length < 3) return null;
    final ps = DronePhotoService.instance;
    final origin = LatLng(
      polygon.map((p) => p.latitude).reduce((a, b) => a + b) / polygon.length,
      polygon.map((p) => p.longitude).reduce((a, b) => a + b) / polygon.length,
    );
    // Ground metres to Mercator metres at this latitude.
    final k = 1 / math.cos(origin.latitude * math.pi / 180);
    final ox = _mx(origin.longitude), oy = _my(origin.latitude);

    // Extent of all kept footprints (local ground metres).
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final photo in photos) {
      for (final c in ps.footprintCorners(photo, origin, options)) {
        minX = math.min(minX, c.$1);
        maxX = math.max(maxX, c.$1);
        minY = math.min(minY, c.$2);
        maxY = math.max(maxY, c.$2);
      }
    }
    final extent = math.max(maxX - minX, maxY - minY) * k;
    if (extent <= 0) return null;
    final pixelSize = math.max(extent / maxPx, 0.05); // Mercator metres/px
    final width = ((maxX - minX) * k / pixelSize).ceil().clamp(1, maxPx);
    final height = ((maxY - minY) * k / pixelSize).ceil().clamp(1, maxPx);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final (kw, kh) = ps.keptSize(photo, options);
      final dstW = kw * k / pixelSize, dstH = kh * k / pixelSize;
      // Decode no larger than needed for the full (uncropped) frame.
      final landscape = photo.width >= photo.height;
      final fullPx = (landscape ? dstW : dstH) / options.keep;
      final target = (landscape ? fullPx : fullPx * photo.width / photo.height)
          .round()
          .clamp(16, 2000);
      ui.Image? img;
      try {
        final bytes = await photo.file.readAsBytes();
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: target,
        );
        img = (await codec.getNextFrame()).image;
        codec.dispose();
      } catch (_) {
        img = null;
      }
      if (img != null) {
        final (lx, ly) = ps.toLocal(photo.position, origin);
        final px = (lx - minX) * k / pixelSize;
        final py = (maxY - ly) * k / pixelSize;
        final iw = img.width.toDouble(), ih = img.height.toDouble();
        final cropW = iw * options.keep, cropH = ih * options.keep;
        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(photo.headingDeg * math.pi / 180);
        canvas.drawImageRect(
          img,
          ui.Rect.fromLTWH((iw - cropW) / 2, (ih - cropH) / 2, cropW, cropH),
          ui.Rect.fromCenter(
            center: ui.Offset.zero,
            width: dstW,
            height: dstH,
          ),
          paint,
        );
        canvas.restore();
        img.dispose();
      }
      onProgress?.call(i + 1, photos.length);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) return null;

    return GeoreferencedImage(
      png: data.buffer.asUint8List(),
      width: width,
      height: height,
      zoom: 0,
      originX: ox + minX * k,
      originY: oy + maxY * k,
      pixelSize: pixelSize,
    );
  }

  /// Saves [mosaic] as `mosaic.png` + `mosaic.json` in [dir].
  Future<DroneMosaic> save(
    Directory dir,
    GeoreferencedImage mosaic,
    int photoCount,
  ) async {
    await dir.create(recursive: true);
    final file = File('${dir.path}/mosaic.png');
    await file.writeAsBytes(mosaic.png, flush: true);
    final east = mosaic.originX + mosaic.width * mosaic.pixelSize;
    final south = mosaic.originY - mosaic.height * mosaic.pixelSize;
    final now = DateTime.now();
    final sw = LatLng(_lat(south), _lon(mosaic.originX));
    final ne = LatLng(_lat(mosaic.originY), _lon(east));
    await File('${dir.path}/mosaic.json').writeAsString(
      jsonEncode({
        'south': sw.latitude,
        'west': sw.longitude,
        'north': ne.latitude,
        'east': ne.longitude,
        'photos': photoCount,
        'createdAt': now.toIso8601String(),
      }),
      flush: true,
    );
    await File('${dir.path}/mosaic.pgw').writeAsString(mosaic.worldFile);
    return DroneMosaic(
      image: file,
      southWest: sw,
      northEast: ne,
      photoCount: photoCount,
      createdAt: now,
    );
  }

  /// Loads a saved mosaic from [dir], or null when none exists.
  Future<DroneMosaic?> load(Directory dir) async {
    final meta = File('${dir.path}/mosaic.json');
    final image = File('${dir.path}/mosaic.png');
    if (!await meta.exists() || !await image.exists()) return null;
    try {
      final m = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      return DroneMosaic(
        image: image,
        southWest: LatLng(
          (m['south'] as num).toDouble(),
          (m['west'] as num).toDouble(),
        ),
        northEast: LatLng(
          (m['north'] as num).toDouble(),
          (m['east'] as num).toDouble(),
        ),
        photoCount: (m['photos'] as num).toInt(),
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

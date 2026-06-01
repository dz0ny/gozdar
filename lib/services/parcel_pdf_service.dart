import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/map_layer.dart';
import '../services/cadastral_service.dart';
import '../services/owner_lookup_service.dart';

/// Builds a printable PDF for a cadastral parcel: a snapshot of the map
/// (base layer + active cadastral overlays, identical to what is shown on
/// screen) with the parcel boundary drawn on top, plus the parcel attributes.
class ParcelPdfService {
  ParcelPdfService._();
  static final ParcelPdfService instance = ParcelPdfService._();

  static const int _tileSize = 256;
  static const double _maxImagePx = 1400;
  static const int _minZoom = 7;

  pw.ThemeData? _theme;

  /// Load the bundled Roboto fonts (cached) so the PDF text supports Slovenian
  /// characters (č, š, ž), which the built-in Helvetica font lacks.
  Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) return _theme!;
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    return _theme = pw.ThemeData.withFont(base: regular, bold: bold);
  }

  /// Render the parcel PDF and return its bytes.
  Future<Uint8List> buildParcelPdf({
    required CadastralParcel parcel,
    required MapLayer baseLayer,
    required Set<MapLayerType> activeOverlays,
    required String workerUrl,
  }) async {
    final owner = OwnerLookupService.instance.lookup(
      parcel.cadastralMunicipality,
      parcel.parcelNumber,
    );

    final mapPng = await _renderMapImage(
      polygon: parcel.polygon,
      baseLayer: baseLayer,
      activeOverlays: activeOverlays,
      workerUrl: workerUrl,
    );

    return _buildDocument(parcel: parcel, owner: owner, mapPng: mapPng);
  }

  // ---------------------------------------------------------------------------
  // Map snapshot rendering (Web Mercator tile stitching + parcel outline)
  // ---------------------------------------------------------------------------

  /// Layers, in draw order, that should appear in the snapshot: the base layer
  /// followed by each active overlay (matching [MapLayerRenderer]).
  List<MapLayer> _layersToRender(
    MapLayer baseLayer,
    Set<MapLayerType> activeOverlays,
    String workerUrl,
  ) {
    return [
      baseLayer,
      ...MapLayer.overlayLayers.where(
        (layer) =>
            activeOverlays.contains(layer.type) &&
            layer.resolveUrlTemplate(workerUrl) != null,
      ),
    ];
  }

  Future<Uint8List?> _renderMapImage({
    required List<LatLng> polygon,
    required MapLayer baseLayer,
    required Set<MapLayerType> activeOverlays,
    required String workerUrl,
  }) async {
    if (polygon.isEmpty) return null;

    // Bounding box of the parcel, padded so the outline isn't flush to the edge.
    var minLat = polygon.first.latitude, maxLat = polygon.first.latitude;
    var minLng = polygon.first.longitude, maxLng = polygon.first.longitude;
    for (final p in polygon) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final padLat = math.max((maxLat - minLat) * 0.35, 0.0004);
    final padLng = math.max((maxLng - minLng) * 0.35, 0.0004);
    minLat -= padLat;
    maxLat += padLat;
    minLng -= padLng;
    maxLng += padLng;

    // Pick the largest zoom that keeps the snapshot within the pixel budget and
    // the base layer's native resolution.
    final maxZoom = baseLayer.nativeMaxZoom;
    var zoom = maxZoom;
    while (zoom > _minZoom) {
      final w = (_lonToTileX(maxLng, zoom) - _lonToTileX(minLng, zoom)) *
          _tileSize;
      final h = (_latToTileY(minLat, zoom) - _latToTileY(maxLat, zoom)) *
          _tileSize;
      if (w <= _maxImagePx && h <= _maxImagePx) break;
      zoom--;
    }

    // Fractional pixel bounds of the bbox at the chosen zoom.
    final x0 = _lonToTileX(minLng, zoom) * _tileSize;
    final x1 = _lonToTileX(maxLng, zoom) * _tileSize;
    final y0 = _latToTileY(maxLat, zoom) * _tileSize; // north = smaller y
    final y1 = _latToTileY(minLat, zoom) * _tileSize;
    final imgW = (x1 - x0).ceil().clamp(1, 4000);
    final imgH = (y1 - y0).ceil().clamp(1, 4000);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, imgW.toDouble(), imgH.toDouble()),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, imgW.toDouble(), imgH.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFE8E8E8),
    );

    final minTileX = (x0 / _tileSize).floor();
    final maxTileX = ((x1 - 1) / _tileSize).floor();
    final minTileY = (y0 / _tileSize).floor();
    final maxTileY = ((y1 - 1) / _tileSize).floor();
    final tilesPerAxis = 1 << zoom;

    // Draw each layer in order; tiles within a layer are fetched in parallel.
    for (final layer in _layersToRender(baseLayer, activeOverlays, workerUrl)) {
      final template = layer.resolveUrlTemplate(workerUrl);
      if (template == null) continue;

      final fetches = <Future<({double dx, double dy, ui.Image? image})>>[];
      for (var tx = minTileX; tx <= maxTileX; tx++) {
        for (var ty = minTileY; ty <= maxTileY; ty++) {
          if (ty < 0 || ty >= tilesPerAxis) continue;
          final wrappedX = tx % tilesPerAxis;
          final url = template
              .replaceAll('{z}', '$zoom')
              .replaceAll('{x}', '$wrappedX')
              .replaceAll('{y}', '$ty');
          final dx = tx * _tileSize - x0;
          final dy = ty * _tileSize - y0;
          fetches.add(
            _fetchTileImage(url).then(
              (img) => (dx: dx, dy: dy, image: img),
            ),
          );
        }
      }

      final tiles = await Future.wait(fetches);
      for (final tile in tiles) {
        final image = tile.image;
        if (image == null) continue;
        canvas.drawImage(
          image,
          ui.Offset(tile.dx, tile.dy),
          ui.Paint(),
        );
        image.dispose();
      }
    }

    // Draw the parcel boundary.
    final points = polygon
        .map(
          (p) => ui.Offset(
            _lonToTileX(p.longitude, zoom) * _tileSize - x0,
            _latToTileY(p.latitude, zoom) * _tileSize - y0,
          ),
        )
        .toList();
    final path = ui.Path()..addPolygon(points, true);
    canvas.drawPath(
      path,
      ui.Paint()
        ..style = ui.PaintingStyle.fill
        ..color = const ui.Color(0x33E53935),
    );
    canvas.drawPath(
      path,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = ui.StrokeJoin.round
        ..color = const ui.Color(0xFFE53935),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(imgW, imgH);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return bytes?.buffer.asUint8List();
  }

  Future<ui.Image?> _fetchTileImage(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {'User-Agent': 'dev.dz0ny.gozdar'},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        debugPrint(
          'PDF TILE HTTP ${response.statusCode} '
          '(${response.bodyBytes.length} bytes): $url',
        );
        return null;
      }
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('PDF TILE ERROR: $url -> $e');
      return null;
    }
  }

  // Web Mercator helpers — fractional tile coordinates.
  double _lonToTileX(double lon, int z) => (lon + 180) / 360 * (1 << z);

  double _latToTileY(double lat, int z) {
    final s = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
    return (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * (1 << z);
  }

  // ---------------------------------------------------------------------------
  // PDF document
  // ---------------------------------------------------------------------------

  Future<Uint8List> _buildDocument({
    required CadastralParcel parcel,
    required OwnerInfo? owner,
    required Uint8List? mapPng,
  }) async {
    final theme = await _loadTheme();
    final doc = pw.Document(theme: theme);
    final dateStr = DateFormat('d. M. yyyy').format(DateTime.now());
    final koValue = owner?.koName != null
        ? '${owner!.koName} (${parcel.cadastralMunicipality})'
        : parcel.cadastralMunicipality.toString();

    // All available attributes (rows with no value are skipped).
    final rows = <({String label, String value})>[
      (label: 'Katastrska občina', value: koValue),
      (label: 'Parcelna številka', value: parcel.parcelNumber),
      (label: 'Površina', value: parcel.formattedArea),
      if (owner != null && owner.displayOwners.isNotEmpty)
        (label: 'Lastnik', value: owner.displayOwners),
      if (owner?.address != null)
        (label: 'Naslov', value: owner!.address!),
      if (owner?.municipality != null)
        (label: 'Občina', value: owner!.municipality!),
    ];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'Parcela ${parcel.parcelNumber}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              // Map sizes to its natural aspect (full width), capped so a tall
              // parcel can't overflow the page — no reserved empty space below.
              pw.ConstrainedBox(
                constraints: const pw.BoxConstraints(maxHeight: 560),
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: mapPng != null
                      ? pw.Image(
                          pw.MemoryImage(mapPng),
                          fit: pw.BoxFit.contain,
                        )
                      : pw.Container(
                          height: 120,
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            'Zemljevida ni bilo mogoče naložiti',
                            style: const pw.TextStyle(color: PdfColors.grey600),
                          ),
                        ),
                ),
              ),
              pw.SizedBox(height: 16),
              for (final row in rows) _attrRow(row.label, row.value),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Gozdar • Izpisano: $dateStr',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Vir: © GURS, © ZGS',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _attrRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

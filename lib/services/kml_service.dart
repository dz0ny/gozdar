import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/parcel.dart';

class KmlService {
  /// Export parcels to KML format
  static Future<void> exportToKml(List<Parcel> parcels) async {
    try {
      final kmlContent = _generateKml(parcels);

      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = '${tempDir.path}/gozdar_parcels_$timestamp.kml';
      final File file = File(filePath);
      await file.writeAsString(kmlContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Gozdar Parcels Export',
          text: 'Exported ${parcels.length} parcels',
        ),
      );
    } catch (e) {
      throw Exception('Failed to export KML: $e');
    }
  }

  /// Generate KML string from parcels
  static String _generateKml(List<Parcel> parcels) {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>Gozdar Parcels</name>');
    buffer.writeln('    <description>Exported from Gozdar app</description>');

    // Style for parcels
    buffer.writeln('    <Style id="parcelStyle">');
    buffer.writeln('      <LineStyle>');
    buffer.writeln('        <color>ff00ff00</color>');
    buffer.writeln('        <width>2</width>');
    buffer.writeln('      </LineStyle>');
    buffer.writeln('      <PolyStyle>');
    buffer.writeln('        <color>4000ff00</color>');
    buffer.writeln('      </PolyStyle>');
    buffer.writeln('    </Style>');

    for (final parcel in parcels) {
      buffer.writeln('    <Placemark>');
      buffer.writeln('      <name>${_escapeXml(parcel.name)}</name>');
      buffer.writeln('      <description>Area: ${parcel.areaFormatted}</description>');
      buffer.writeln('      <styleUrl>#parcelStyle</styleUrl>');
      buffer.writeln('      <Polygon>');
      buffer.writeln('        <outerBoundaryIs>');
      buffer.writeln('          <LinearRing>');
      buffer.writeln('            <coordinates>');

      // Add coordinates (longitude,latitude,altitude)
      for (final point in parcel.polygon) {
        buffer.writeln('              ${point.longitude},${point.latitude},0');
      }
      // Close the polygon by repeating the first point
      if (parcel.polygon.isNotEmpty) {
        buffer.writeln('              ${parcel.polygon.first.longitude},${parcel.polygon.first.latitude},0');
      }

      buffer.writeln('            </coordinates>');
      buffer.writeln('          </LinearRing>');
      buffer.writeln('        </outerBoundaryIs>');
      buffer.writeln('      </Polygon>');
      buffer.writeln('    </Placemark>');
    }

    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');

    return buffer.toString();
  }

  /// Import parcels from KML file content
  static List<Parcel> importFromKml(String kmlContent) {
    final parcels = <Parcel>[];

    try {
      // Simple XML parsing for KML placemarks with polygons
      final placemarkRegex = RegExp(
        r'<Placemark>(.*?)</Placemark>',
        dotAll: true,
      );

      final placemarks = placemarkRegex.allMatches(kmlContent);

      for (final match in placemarks) {
        final placemark = match.group(1) ?? '';

        // Extract name
        final nameMatch = RegExp(r'<name>(.*?)</name>').firstMatch(placemark);
        final name = nameMatch != null
            ? _unescapeXml(nameMatch.group(1) ?? 'Imported Parcel')
            : 'Imported Parcel';

        // Extract coordinates from Polygon
        final coordsMatch = RegExp(
          r'<Polygon>.*?<coordinates>(.*?)</coordinates>.*?</Polygon>',
          dotAll: true,
        ).firstMatch(placemark);

        if (coordsMatch != null) {
          final coordsStr = coordsMatch.group(1) ?? '';
          final polygon = _parseCoordinates(coordsStr);

          if (polygon.length >= 3) {
            parcels.add(Parcel(
              name: name,
              polygon: polygon,
            ));
          }
        }

        // Also check for LinearRing without Polygon wrapper (for some KML formats)
        if (coordsMatch == null) {
          final ringMatch = RegExp(
            r'<LinearRing>.*?<coordinates>(.*?)</coordinates>.*?</LinearRing>',
            dotAll: true,
          ).firstMatch(placemark);

          if (ringMatch != null) {
            final coordsStr = ringMatch.group(1) ?? '';
            final polygon = _parseCoordinates(coordsStr);

            if (polygon.length >= 3) {
              parcels.add(Parcel(
                name: name,
                polygon: polygon,
              ));
            }
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to parse KML: $e');
    }

    return parcels;
  }

  /// Parse KML coordinates string to list of LatLng
  static List<LatLng> _parseCoordinates(String coordsStr) {
    final polygon = <LatLng>[];

    // Split by whitespace and newlines
    final coords = coordsStr.trim().split(RegExp(r'\s+'));

    for (final coord in coords) {
      if (coord.isEmpty) continue;

      // Format: longitude,latitude[,altitude]
      final parts = coord.split(',');
      if (parts.length >= 2) {
        final lng = double.tryParse(parts[0].trim());
        final lat = double.tryParse(parts[1].trim());

        if (lng != null && lat != null) {
          polygon.add(LatLng(lat, lng));
        }
      }
    }

    // Remove duplicate last point if present (KML closes polygons)
    if (polygon.length >= 2 &&
        polygon.first.latitude == polygon.last.latitude &&
        polygon.first.longitude == polygon.last.longitude) {
      polygon.removeLast();
    }

    return polygon;
  }

  /// Escape special XML characters
  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Unescape XML entities
  static String _unescapeXml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}

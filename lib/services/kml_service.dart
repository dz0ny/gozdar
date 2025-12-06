import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/parcel.dart';
import '../models/log_entry.dart';
import '../models/map_location.dart';

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
      buffer.writeln(
        '      <description>Area: ${parcel.areaFormatted}</description>',
      );
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
        buffer.writeln(
          '              ${parcel.polygon.first.longitude},${parcel.polygon.first.latitude},0',
        );
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
            parcels.add(Parcel(name: name, polygon: polygon));
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
              parcels.add(Parcel(name: name, polygon: polygon));
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

  /// Export a single parcel with all its data (logs, sečnja, locations)
  static Future<void> exportParcelWithData({
    required Parcel parcel,
    required List<LogEntry> logs,
    required List<MapLocation> secnja,
    required List<MapLocation> locations,
  }) async {
    try {
      final kmlContent = _generateParcelKml(
        parcel: parcel,
        logs: logs,
        secnja: secnja,
        locations: locations,
      );

      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String safeName = parcel.name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final String filePath = '${tempDir.path}/${safeName}_$timestamp.kml';
      final File file = File(filePath);
      await file.writeAsString(kmlContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Parcela ${parcel.name}',
          text:
              'Izvoz parcele ${parcel.name} z ${logs.length} hlodi, ${secnja.length} sečnjami in ${locations.length} točkami',
        ),
      );
    } catch (e) {
      throw Exception('Failed to export KML: $e');
    }
  }

  /// Generate KML for a single parcel with all data
  static String _generateParcelKml({
    required Parcel parcel,
    required List<LogEntry> logs,
    required List<MapLocation> secnja,
    required List<MapLocation> locations,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>${_escapeXml(parcel.name)}</name>');
    buffer.writeln(
      '    <description>Izvoženo iz aplikacije Gozdar</description>',
    );

    // Styles
    buffer.writeln('    <Style id="parcelStyle">');
    buffer.writeln(
      '      <LineStyle><color>ff00ff00</color><width>2</width></LineStyle>',
    );
    buffer.writeln('      <PolyStyle><color>4000ff00</color></PolyStyle>');
    buffer.writeln('    </Style>');
    buffer.writeln('    <Style id="logStyle">');
    buffer.writeln(
      '      <IconStyle><color>ff2d5ba6</color><scale>1.0</scale>',
    );
    buffer.writeln(
      '        <Icon><href>http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png</href></Icon>',
    );
    buffer.writeln('      </IconStyle>');
    buffer.writeln('    </Style>');
    buffer.writeln('    <Style id="secnjaStyle">');
    buffer.writeln(
      '      <IconStyle><color>ff0080ff</color><scale>1.0</scale>',
    );
    buffer.writeln(
      '        <Icon><href>http://maps.google.com/mapfiles/kml/shapes/target.png</href></Icon>',
    );
    buffer.writeln('      </IconStyle>');
    buffer.writeln('    </Style>');
    buffer.writeln('    <Style id="locationStyle">');
    buffer.writeln(
      '      <IconStyle><color>ff00a5ff</color><scale>0.8</scale>',
    );
    buffer.writeln(
      '        <Icon><href>http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png</href></Icon>',
    );
    buffer.writeln('      </IconStyle>');
    buffer.writeln('    </Style>');

    // Parcel polygon
    buffer.writeln('    <Folder>');
    buffer.writeln('      <name>Parcela</name>');
    buffer.writeln('      <Placemark>');
    buffer.writeln('        <name>${_escapeXml(parcel.name)}</name>');

    // Build description with parcel details
    final descParts = <String>[];
    descParts.add('Površina: ${parcel.areaFormatted}');
    if (parcel.cadastralMunicipality != null) {
      descParts.add('KO: ${parcel.cadastralMunicipality}');
    }
    if (parcel.parcelNumber != null) {
      descParts.add('Št. parcele: ${parcel.parcelNumber}');
    }
    if (parcel.owner != null && parcel.owner!.isNotEmpty) {
      descParts.add('Lastnik: ${parcel.owner}');
    }
    if (parcel.woodAllowance > 0) {
      descParts.add(
        'Dovoljen posek: ${parcel.woodAllowance.toStringAsFixed(2)} m³',
      );
    }
    if (parcel.woodCut > 0) {
      descParts.add('Posekano: ${parcel.woodCut.toStringAsFixed(2)} m³');
    }
    if (parcel.treesCut > 0) {
      descParts.add('Posekanih dreves: ${parcel.treesCut}');
    }

    buffer.writeln(
      '        <description>${_escapeXml(descParts.join('\n'))}</description>',
    );
    buffer.writeln('        <styleUrl>#parcelStyle</styleUrl>');
    buffer.writeln('        <Polygon>');
    buffer.writeln('          <outerBoundaryIs>');
    buffer.writeln('            <LinearRing>');
    buffer.writeln('              <coordinates>');
    for (final point in parcel.polygon) {
      buffer.writeln('                ${point.longitude},${point.latitude},0');
    }
    if (parcel.polygon.isNotEmpty) {
      buffer.writeln(
        '                ${parcel.polygon.first.longitude},${parcel.polygon.first.latitude},0',
      );
    }
    buffer.writeln('              </coordinates>');
    buffer.writeln('            </LinearRing>');
    buffer.writeln('          </outerBoundaryIs>');
    buffer.writeln('        </Polygon>');
    buffer.writeln('      </Placemark>');
    buffer.writeln('    </Folder>');

    // Logs folder
    if (logs.isNotEmpty) {
      buffer.writeln('    <Folder>');
      buffer.writeln('      <name>Hlodovina (${logs.length})</name>');
      for (final log in logs) {
        if (log.latitude != null && log.longitude != null) {
          buffer.writeln('      <Placemark>');
          buffer.writeln(
            '        <name>${log.volume.toStringAsFixed(3)} m³</name>',
          );
          final logDesc = <String>[];
          logDesc.add('Volumen: ${log.volume.toStringAsFixed(4)} m³');
          if (log.diameter != null) {
            logDesc.add('Premer: ${log.diameter!.toStringAsFixed(0)} cm');
          }
          if (log.length != null) {
            logDesc.add('Dolžina: ${log.length!.toStringAsFixed(1)} m');
          }
          if (log.notes != null && log.notes!.isNotEmpty) {
            logDesc.add('Opombe: ${log.notes}');
          }
          buffer.writeln(
            '        <description>${_escapeXml(logDesc.join('\n'))}</description>',
          );
          buffer.writeln('        <styleUrl>#logStyle</styleUrl>');
          buffer.writeln(
            '        <Point><coordinates>${log.longitude},${log.latitude},0</coordinates></Point>',
          );
          buffer.writeln('      </Placemark>');
        }
      }
      buffer.writeln('    </Folder>');
    }

    // Sečnja folder
    if (secnja.isNotEmpty) {
      buffer.writeln('    <Folder>');
      buffer.writeln('      <name>Sečnja (${secnja.length})</name>');
      for (final loc in secnja) {
        buffer.writeln('      <Placemark>');
        buffer.writeln('        <name>${_escapeXml(loc.name)}</name>');
        buffer.writeln('        <description>Drevo za posek</description>');
        buffer.writeln('        <styleUrl>#secnjaStyle</styleUrl>');
        buffer.writeln(
          '        <Point><coordinates>${loc.longitude},${loc.latitude},0</coordinates></Point>',
        );
        buffer.writeln('      </Placemark>');
      }
      buffer.writeln('    </Folder>');
    }

    // Locations folder
    if (locations.isNotEmpty) {
      buffer.writeln('    <Folder>');
      buffer.writeln(
        '      <name>Shranjene točke (${locations.length})</name>',
      );
      for (final loc in locations) {
        buffer.writeln('      <Placemark>');
        buffer.writeln('        <name>${_escapeXml(loc.name)}</name>');
        buffer.writeln('        <styleUrl>#locationStyle</styleUrl>');
        buffer.writeln(
          '        <Point><coordinates>${loc.longitude},${loc.latitude},0</coordinates></Point>',
        );
        buffer.writeln('      </Placemark>');
      }
      buffer.writeln('    </Folder>');
    }

    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');

    return buffer.toString();
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

  /// Import parcel with all data from KML file content
  /// Returns a record with parcel, logs, sečnja and locations
  static ParcelImportData? importParcelWithData(String kmlContent) {
    try {
      Parcel? parcel;
      final logs = <LogEntry>[];
      final secnja = <MapLocation>[];
      final locations = <MapLocation>[];

      // Find all folders
      final folderRegex = RegExp(r'<Folder>(.*?)</Folder>', dotAll: true);

      final folders = folderRegex.allMatches(kmlContent);

      for (final folderMatch in folders) {
        final folderContent = folderMatch.group(1) ?? '';

        // Get folder name
        final nameMatch = RegExp(
          r'<name>(.*?)</name>',
        ).firstMatch(folderContent);
        final folderName = nameMatch != null
            ? _unescapeXml(nameMatch.group(1) ?? '')
            : '';

        // Parse placemarks in this folder
        final placemarkRegex = RegExp(
          r'<Placemark>(.*?)</Placemark>',
          dotAll: true,
        );
        final placemarks = placemarkRegex.allMatches(folderContent);

        for (final match in placemarks) {
          final placemark = match.group(1) ?? '';

          if (folderName.toLowerCase().contains('parcela')) {
            // Parse parcel polygon
            parcel = _parseParcelPlacemark(placemark);
          } else if (folderName.toLowerCase().contains('hlod')) {
            // Parse log point
            final log = _parseLogPlacemark(placemark);
            if (log != null) logs.add(log);
          } else if (folderName.toLowerCase().contains('sečnj') ||
              folderName.toLowerCase().contains('secnj')) {
            // Parse sečnja point
            final loc = _parseLocationPlacemark(placemark, LocationType.secnja);
            if (loc != null) secnja.add(loc);
          } else if (folderName.toLowerCase().contains('točk') ||
              folderName.toLowerCase().contains('tock') ||
              folderName.toLowerCase().contains('lokacij')) {
            // Parse saved location point
            final loc = _parseLocationPlacemark(placemark, LocationType.point);
            if (loc != null) locations.add(loc);
          }
        }
      }

      // If no folders found, try to parse as simple KML with just parcel
      if (parcel == null) {
        final simpleParcels = importFromKml(kmlContent);
        if (simpleParcels.isNotEmpty) {
          parcel = simpleParcels.first;
        }
      }

      if (parcel == null) return null;

      return ParcelImportData(
        parcel: parcel,
        logs: logs,
        secnja: secnja,
        locations: locations,
      );
    } catch (e) {
      throw Exception('Failed to parse KML with data: $e');
    }
  }

  /// Parse a parcel from a placemark
  static Parcel? _parseParcelPlacemark(String placemark) {
    // Extract name
    final nameMatch = RegExp(r'<name>(.*?)</name>').firstMatch(placemark);
    final name = nameMatch != null
        ? _unescapeXml(nameMatch.group(1) ?? 'Uvožena parcela')
        : 'Uvožena parcela';

    // Extract description for metadata
    final descMatch = RegExp(
      r'<description>(.*?)</description>',
      dotAll: true,
    ).firstMatch(placemark);
    final description = descMatch != null
        ? _unescapeXml(descMatch.group(1) ?? '')
        : '';

    // Parse metadata from description
    int? ko;
    String? parcelNumber;
    String? owner;
    double woodAllowance = 0;
    double woodCut = 0;
    int treesCut = 0;

    final koMatch = RegExp(r'KO:\s*(\d+)').firstMatch(description);
    if (koMatch != null) ko = int.tryParse(koMatch.group(1) ?? '');

    final parcelNumMatch = RegExp(
      r'Št\.\s*parcele:\s*(.+)',
    ).firstMatch(description);
    if (parcelNumMatch != null) parcelNumber = parcelNumMatch.group(1)?.trim();

    final ownerMatch = RegExp(r'Lastnik:\s*(.+)').firstMatch(description);
    if (ownerMatch != null) owner = ownerMatch.group(1)?.trim();

    final allowanceMatch = RegExp(
      r'Dovoljen posek:\s*([\d.]+)',
    ).firstMatch(description);
    if (allowanceMatch != null) {
      woodAllowance = double.tryParse(allowanceMatch.group(1) ?? '0') ?? 0;
    }

    final cutMatch = RegExp(r'Posekano:\s*([\d.]+)').firstMatch(description);
    if (cutMatch != null) {
      woodCut = double.tryParse(cutMatch.group(1) ?? '0') ?? 0;
    }

    final treesMatch = RegExp(
      r'Posekanih dreves:\s*(\d+)',
    ).firstMatch(description);
    if (treesMatch != null) {
      treesCut = int.tryParse(treesMatch.group(1) ?? '0') ?? 0;
    }

    // Extract coordinates
    final coordsMatch = RegExp(
      r'<Polygon>.*?<coordinates>(.*?)</coordinates>.*?</Polygon>',
      dotAll: true,
    ).firstMatch(placemark);

    if (coordsMatch != null) {
      final coordsStr = coordsMatch.group(1) ?? '';
      final polygon = _parseCoordinates(coordsStr);

      if (polygon.length >= 3) {
        return Parcel(
          name: name,
          polygon: polygon,
          cadastralMunicipality: ko,
          parcelNumber: parcelNumber,
          owner: owner,
          woodAllowance: woodAllowance,
          woodCut: woodCut,
          treesCut: treesCut,
        );
      }
    }

    return null;
  }

  /// Parse a log entry from a placemark
  static LogEntry? _parseLogPlacemark(String placemark) {
    // Extract coordinates
    final coordMatch = RegExp(
      r'<Point>\s*<coordinates>(.*?)</coordinates>\s*</Point>',
      dotAll: true,
    ).firstMatch(placemark);
    if (coordMatch == null) return null;

    final coordStr = coordMatch.group(1)?.trim() ?? '';
    final parts = coordStr.split(',');
    if (parts.length < 2) return null;

    final lng = double.tryParse(parts[0].trim());
    final lat = double.tryParse(parts[1].trim());
    if (lng == null || lat == null) return null;

    // Extract description for metadata
    final descMatch = RegExp(
      r'<description>(.*?)</description>',
      dotAll: true,
    ).firstMatch(placemark);
    final description = descMatch != null
        ? _unescapeXml(descMatch.group(1) ?? '')
        : '';

    double volume = 0;
    double? diameter;
    double? length;
    String? notes;

    final volumeMatch = RegExp(r'Volumen:\s*([\d.]+)').firstMatch(description);
    if (volumeMatch != null)
      volume = double.tryParse(volumeMatch.group(1) ?? '0') ?? 0;

    final diameterMatch = RegExp(r'Premer:\s*([\d.]+)').firstMatch(description);
    if (diameterMatch != null)
      diameter = double.tryParse(diameterMatch.group(1) ?? '');

    final lengthMatch = RegExp(r'Dolžina:\s*([\d.]+)').firstMatch(description);
    if (lengthMatch != null)
      length = double.tryParse(lengthMatch.group(1) ?? '');

    final notesMatch = RegExp(r'Opombe:\s*(.+)').firstMatch(description);
    if (notesMatch != null) notes = notesMatch.group(1)?.trim();

    // If no volume in description, try to parse from name
    if (volume == 0) {
      final nameMatch = RegExp(r'<name>(.*?)</name>').firstMatch(placemark);
      if (nameMatch != null) {
        final nameVolumeMatch = RegExp(
          r'([\d.]+)\s*m³',
        ).firstMatch(nameMatch.group(1) ?? '');
        if (nameVolumeMatch != null) {
          volume = double.tryParse(nameVolumeMatch.group(1) ?? '0') ?? 0;
        }
      }
    }

    if (volume <= 0) return null;

    return LogEntry(
      volume: volume,
      diameter: diameter,
      length: length,
      latitude: lat,
      longitude: lng,
      notes: notes,
    );
  }

  /// Parse a location from a placemark
  static MapLocation? _parseLocationPlacemark(
    String placemark,
    LocationType type,
  ) {
    // Extract name
    final nameMatch = RegExp(r'<name>(.*?)</name>').firstMatch(placemark);
    final name = nameMatch != null
        ? _unescapeXml(nameMatch.group(1) ?? 'Uvožena točka')
        : 'Uvožena točka';

    // Extract coordinates
    final coordMatch = RegExp(
      r'<Point>\s*<coordinates>(.*?)</coordinates>\s*</Point>',
      dotAll: true,
    ).firstMatch(placemark);
    if (coordMatch == null) return null;

    final coordStr = coordMatch.group(1)?.trim() ?? '';
    final parts = coordStr.split(',');
    if (parts.length < 2) return null;

    final lng = double.tryParse(parts[0].trim());
    final lat = double.tryParse(parts[1].trim());
    if (lng == null || lat == null) return null;

    return MapLocation(name: name, latitude: lat, longitude: lng, type: type);
  }
}

/// Data structure for imported parcel with all associated data
class ParcelImportData {
  final Parcel parcel;
  final List<LogEntry> logs;
  final List<MapLocation> secnja;
  final List<MapLocation> locations;

  const ParcelImportData({
    required this.parcel,
    required this.logs,
    required this.secnja,
    required this.locations,
  });

  /// Total number of items (excluding parcel)
  int get totalItems => logs.length + secnja.length + locations.length;
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;

import 'drone_mission_service.dart';
import 'parcel_pdf_service.dart' show GeoreferencedImage;

/// Packs everything needed to fly and later process a parcel survey into one
/// ZIP: flight plan, parcel boundary, reference orthophoto and the photos.
class DroneBundleService {
  DroneBundleService._();
  static final DroneBundleService instance = DroneBundleService._();

  static const _webMercatorPrj =
      'PROJCS["WGS_1984_Web_Mercator_Auxiliary_Sphere",GEOGCS["GCS_WGS_1984",'
      'DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],'
      'PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],'
      'PROJECTION["Mercator_Auxiliary_Sphere"],PARAMETER["False_Easting",0.0],'
      'PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",0.0],'
      'PARAMETER["Standard_Parallel_1",0.0],'
      'PARAMETER["Auxiliary_Sphere_Type",0.0],UNIT["Meter",1.0]]';

  /// GeoJSON polygon (lon/lat order) of the parcel boundary.
  String parcelGeoJson({
    required String name,
    required String? cadastralId,
    required List<LatLng> polygon,
  }) {
    final ring = [
      for (final pt in polygon) [pt.longitude, pt.latitude],
    ];
    if (ring.isNotEmpty) ring.add(ring.first);
    return const JsonEncoder.withIndent('  ').convert({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'name': name, 'cadastralId': cadastralId},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [ring],
          },
        },
      ],
    });
  }

  /// Writes the bundle to [outPath] and returns the file.
  ///
  /// Photos are streamed from disk so large surveys do not load into memory.
  Future<File> writeBundle({
    required String outPath,
    required String parcelName,
    required String? cadastralId,
    required List<LatLng> polygon,
    required DroneMissionOptions options,
    required List<MissionWaypoint> waypoints,
    required Uint8List kmz,
    GeoreferencedImage? referenceOrtho,
    List<File> photos = const [],
    String appVersion = '',
  }) async {
    final svc = DroneMissionService.instance;
    final encoder = ZipFileEncoder()..create(outPath);
    try {
      void addBytes(String path, List<int> data) =>
          encoder.addArchiveFile(ArchiveFile(path, data.length, data));

      addBytes('mission/mission.kmz', kmz);
      addBytes(
        'parcel.geojson',
        utf8.encode(
          parcelGeoJson(
            name: parcelName,
            cadastralId: cadastralId,
            polygon: polygon,
          ),
        ),
      );
      if (referenceOrtho != null) {
        addBytes('reference-ortho.png', referenceOrtho.png);
        addBytes('reference-ortho.pgw', utf8.encode(referenceOrtho.worldFile));
        addBytes('reference-ortho.prj', utf8.encode(_webMercatorPrj));
      }

      final used = <String>{};
      for (final photo in photos) {
        var name = p.basename(photo.path);
        if (!used.add(name)) {
          name = '${used.length}_$name';
          used.add(name);
        }
        await encoder.addFile(photo, 'images/$name');
      }

      addBytes(
        'manifest.json',
        utf8.encode(
          const JsonEncoder.withIndent('  ').convert({
            'format': 'gozdar-drone-bundle',
            'version': 1,
            'appVersion': appVersion,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'parcel': {'name': parcelName, 'cadastralId': cadastralId},
            'crs': 'EPSG:4326',
            'mission': {
              'file': 'mission/mission.kmz',
              'altitudeM': options.altitudeM,
              'speedMs': options.speedMs,
              'sideOverlap': options.sideOverlap,
              'headingDeg': options.headingDeg,
              'waypoints': waypoints.length,
              'pathLengthM': svc.pathLengthM(waypoints).round(),
            },
            if (referenceOrtho != null)
              'referenceOrtho': {
                'file': 'reference-ortho.png',
                'worldFile': 'reference-ortho.pgw',
                'crs': 'EPSG:3857',
                'zoom': referenceOrtho.zoom,
                'pixelSizeM': referenceOrtho.pixelSize,
                'width': referenceOrtho.width,
                'height': referenceOrtho.height,
              },
            'images': {'count': photos.length, 'folder': 'images/'},
          }),
        ),
      );
    } finally {
      encoder.close();
    }
    return File(outPath);
  }
}

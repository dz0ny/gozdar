import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'http_cache_service.dart';

/// Service for querying Slovenian WMS data via GetFeatureInfo
class CadastralService {
  static const String _wmsBaseUrl = 'https://prostor.zgs.gov.si/geoserver/pregledovalnik/wms';
  static const String _wfsApiUrl = 'https://gozdar-proxy.dz0ny.workers.dev/api/wfs';

  final HttpCacheService _httpCache = HttpCacheService();

  // Singleton instance
  static final CadastralService _instance = CadastralService._internal();
  factory CadastralService() => _instance;
  CadastralService._internal();

  // EPSG:3794 projection for Slovenia
  static proj4.Projection? _epsg3794;
  static proj4.Projection? _wgs84;

  static void _initProjections() {
    if (_epsg3794 == null) {
      const epsg3794Def =
          '+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 '
          '+x_0=500000 +y_0=-5000000 +ellps=GRS80 '
          '+towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs';

      try {
        _epsg3794 = proj4.Projection.get('EPSG:3794') ??
            proj4.Projection.add('EPSG:3794', epsg3794Def);
      } catch (e) {
        _epsg3794 = proj4.Projection.get('EPSG:3794');
      }

      // Some proj4dart setups may not have EPSG:4326 pre-registered.
      _wgs84 = proj4.Projection.get('EPSG:4326') ??
          proj4.Projection.add('EPSG:4326', '+proj=longlat +datum=WGS84 +no_defs');
    }
  }

  /// Convert WGS84 (lat/lng) to EPSG:3794 (Slovenian grid)
  static proj4.Point latLngToEpsg3794(LatLng latLng) {
    _initProjections();
    final wgs84Point = proj4.Point(x: latLng.longitude, y: latLng.latitude);
    return _wgs84!.transform(_epsg3794!, wgs84Point);
  }

  /// Convert EPSG:3794 point to WGS84 LatLng
  static LatLng epsg3794ToLatLng(double x, double y) {
    _initProjections();
    final epsg3794Point = proj4.Point(x: x, y: y);
    final wgs84Point = _epsg3794!.transform(_wgs84!, epsg3794Point);
    return LatLng(wgs84Point.y, wgs84Point.x);
  }

  /// Convert polygon coordinates from EPSG:3794 to WGS84
  static List<LatLng> convertPolygonToLatLng(List<List<double>> coordinates) {
    return coordinates.map((coord) {
      return epsg3794ToLatLng(coord[0], coord[1]);
    }).toList();
  }

  /// Generic WMS GetFeatureInfo query for any layer
  /// Returns raw GeoJSON features or null on error
  Future<List<Map<String, dynamic>>?> queryLayerAtLocation(
    LatLng location,
    String layerName, {
    int featureCount = 50,
    double boxSize = 30.0,
  }) async {
    try {
      // Convert to EPSG:3794
      final point = latLngToEpsg3794(location);

      // Create a small bounding box around the point
      final minX = point.x - boxSize;
      final minY = point.y - boxSize;
      final maxX = point.x + boxSize;
      final maxY = point.y + boxSize;

      // Build WMS 1.3.0 GetFeatureInfo request
      final uri = Uri.parse(_wmsBaseUrl).replace(queryParameters: {
        'SERVICE': 'WMS',
        'VERSION': '1.3.0',
        'REQUEST': 'GetFeatureInfo',
        'FORMAT': 'image/png',
        'TRANSPARENT': 'true',
        'QUERY_LAYERS': layerName,
        'STYLES': '',
        'LAYERS': layerName,
        'EXCEPTIONS': 'INIMAGE',
        'INFO_FORMAT': 'application/json',
        'FEATURE_COUNT': featureCount.toString(),
        'I': '50',
        'J': '50',
        'CRS': 'EPSG:3794',
        'WIDTH': '101',
        'HEIGHT': '101',
        'BBOX': '$minX,$minY,$maxX,$maxY',
      });

      final response = await _httpCache.get(uri, timeout: const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>?;

      if (features == null || features.isEmpty) {
        return null;
      }

      return features.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error querying layer $layerName: $e');
      return null;
    }
  }

  /// Query cadastral parcel at given location
  /// Returns null if no parcel found or on error
  Future<CadastralParcel?> queryParcelAtLocation(LatLng location) async {
    final features = await queryLayerAtLocation(
      location,
      'pregledovalnik:kn_parcele',
    );

    if (features == null || features.isEmpty) {
      return null;
    }

    return CadastralParcel.fromGeoJson(features.first);
  }

  /// Query cadastral parcel by KO number and parcel number
  /// Returns null if no parcel found or on error
  Future<WfsParcel?> queryParcelByKoAndNumber(
    String koNumber,
    String parcelNumber,
  ) async {
    try {
      // URL encode parcel number (handles slashes like "1/1")
      final encodedParcel = Uri.encodeComponent(parcelNumber);
      final uri = Uri.parse('$_wfsApiUrl/parcel/ko/$koNumber/$encodedParcel');

      final response = await _httpCache.get(uri, timeout: const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>?;

      if (features == null || features.isEmpty) {
        return null;
      }

      return WfsParcel.fromGeoJson(features.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error querying parcel by KO $koNumber and number $parcelNumber: $e');
      return null;
    }
  }

  /// Query forest stand (sestoj) at given location
  Future<WmsFeature?> queryForestStandAtLocation(LatLng location) async {
    final features = await queryLayerAtLocation(
      location,
      'pregledovalnik:sestoji',
    );

    if (features == null || features.isEmpty) {
      return null;
    }

    return WmsFeature.fromGeoJson(features.first, 'Sestoj');
  }

  /// Query forest section (odsek) at given location
  Future<WmsFeature?> queryForestSectionAtLocation(LatLng location) async {
    final features = await queryLayerAtLocation(
      location,
      'pregledovalnik:odseki_gozdni',
    );

    if (features == null || features.isEmpty) {
      return null;
    }

    return WmsFeature.fromGeoJson(features.first, 'Odsek');
  }

  /// Query protected area at given location
  Future<WmsFeature?> queryProtectedAreaAtLocation(LatLng location) async {
    final features = await queryLayerAtLocation(
      location,
      'pregledovalnik:zavarovana_obmocja_poligoni',
    );

    if (features == null || features.isEmpty) {
      return null;
    }

    return WmsFeature.fromGeoJson(features.first, 'Zavarovano obmocje');
  }

  /// Query multiple layers at once and return all results
  Future<Map<String, List<WmsFeature>>> queryMultipleLayersAtLocation(
    LatLng location,
    List<String> layerNames,
  ) async {
    final results = <String, List<WmsFeature>>{};

    // Query all layers in parallel
    final futures = layerNames.map((layer) async {
      final features = await queryLayerAtLocation(location, layer);
      if (features != null && features.isNotEmpty) {
        results[layer] = features
            .map((f) => WmsFeature.fromGeoJson(f, _getLayerDisplayName(layer)))
            .toList();
      }
    });

    await Future.wait(futures);
    return results;
  }

  /// Get display name for a layer
  String _getLayerDisplayName(String layerName) {
    final names = {
      'pregledovalnik:kn_parcele': 'Parcela',
      'pregledovalnik:sestoji': 'Sestoj',
      'pregledovalnik:odseki_gozdni': 'Odsek',
      'pregledovalnik:revirji': 'Revir',
      'pregledovalnik:gge': 'GGE',
      'pregledovalnik:ggo': 'GGO',
      'pregledovalnik:gozdni_rezervati': 'Gozdni rezervat',
      'pregledovalnik:varovalni_gozdovi': 'Varovalni gozd',
      'pregledovalnik:zavarovana_obmocja_poligoni': 'Zavarovano obmocje',
      'pregledovalnik:naravne_vrednote_poligoni': 'Naravna vrednota',
      'pregledovalnik:epo_poligoni': 'EPO',
      'pregledovalnik:lovisca': 'Lovisce',
      'pregledovalnik:pozarna_ogrozenost': 'Pozarna ogrozenost',
      'pregledovalnik:NEP_RPE_OBCINE': 'Obcina',
      'pregledovalnik:KN_KATASTRSKE_OBCINE': 'Katastrska obcina',
    };
    return names[layerName] ?? layerName.split(':').last;
  }
}

/// Generic WMS feature for any layer
class WmsFeature {
  final String id;
  final String layerType;
  final Map<String, dynamic> properties;
  final List<LatLng>? polygon;

  const WmsFeature({
    required this.id,
    required this.layerType,
    required this.properties,
    this.polygon,
  });

  factory WmsFeature.fromGeoJson(Map<String, dynamic> feature, String layerType) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>?;

    List<LatLng>? polygon;
    if (geometry != null) {
      try {
        final geomType = geometry['type'] as String?;
        final coordinates = geometry['coordinates'] as List<dynamic>?;

        if (coordinates != null && coordinates.isNotEmpty) {
          List<dynamic> ring;

          if (geomType == 'MultiPolygon') {
            final firstPolygon = coordinates[0] as List<dynamic>;
            ring = firstPolygon[0] as List<dynamic>;
          } else if (geomType == 'Polygon') {
            ring = coordinates[0] as List<dynamic>;
          } else {
            ring = [];
          }

          if (ring.isNotEmpty) {
            polygon = ring.map((coord) {
              final c = coord as List<dynamic>;
              return CadastralService.epsg3794ToLatLng(
                (c[0] as num).toDouble(),
                (c[1] as num).toDouble(),
              );
            }).toList();
          }
        }
      } catch (e) {
        debugPrint('Error parsing WmsFeature geometry: $e');
      }
    }

    return WmsFeature(
      id: feature['id'] as String? ?? '',
      layerType: layerType,
      properties: properties,
      polygon: polygon,
    );
  }

  /// Get a property value by key
  dynamic operator [](String key) => properties[key];

  /// Get display name based on common property names
  String get displayName {
    // Try common name properties
    final nameProps = ['ime', 'naziv', 'name', 'parcela', 'oznaka'];
    for (final prop in nameProps) {
      if (properties.containsKey(prop) && properties[prop] != null) {
        return '$layerType: ${properties[prop]}';
      }
    }
    return layerType;
  }
}

/// Represents a cadastral parcel from the WMS service
class CadastralParcel {
  final String id;
  final int cadastralMunicipality; // ko (katastrska obcina)
  final String parcelNumber; // parcela
  final double area; // povrsina in m²
  final List<LatLng> polygon; // Converted to WGS84

  const CadastralParcel({
    required this.id,
    required this.cadastralMunicipality,
    required this.parcelNumber,
    required this.area,
    required this.polygon,
  });

  /// Create from GeoJSON feature
  factory CadastralParcel.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;

    // Parse polygon coordinates
    // MultiPolygon: coordinates[0] is the first polygon, [0] is the outer ring
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final firstPolygon = coordinates[0] as List<dynamic>;
    final outerRing = firstPolygon[0] as List<dynamic>;

    final polygonCoords = outerRing.map((coord) {
      final c = coord as List<dynamic>;
      return [(c[0] as num).toDouble(), (c[1] as num).toDouble()];
    }).toList();

    // Convert to WGS84
    final latLngPolygon = CadastralService.convertPolygonToLatLng(polygonCoords);

    return CadastralParcel(
      id: feature['id'] as String? ?? '',
      cadastralMunicipality: properties['ko'] as int? ?? 0,
      parcelNumber: properties['parcela']?.toString() ?? '',
      area: (properties['povrsina'] as num?)?.toDouble() ?? 0.0,
      polygon: latLngPolygon,
    );
  }

  /// Get formatted area string
  String get formattedArea {
    if (area >= 10000) {
      return '${(area / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${area.toStringAsFixed(0)} m²';
    }
  }

  /// Get display name for the parcel
  String get displayName => 'Parcela $parcelNumber (KO $cadastralMunicipality)';
}

/// Represents a cadastral parcel from the WFS API (GURS official data)
class WfsParcel {
  final String localId;
  final String label;
  final String nationalCadastralReference;
  final double area; // in m²
  final List<LatLng> polygon; // Converted to WGS84
  final LatLng? referencePoint; // Centroid

  const WfsParcel({
    required this.localId,
    required this.label,
    required this.nationalCadastralReference,
    required this.area,
    required this.polygon,
    this.referencePoint,
  });

  /// Create from WFS GeoJSON feature
  factory WfsParcel.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;

    // Parse area value
    final areaValue = properties['areaValue'];
    double area = 0.0;
    if (areaValue is Map && areaValue['value'] != null) {
      area = (areaValue['value'] as num).toDouble();
    } else if (areaValue is num) {
      area = areaValue.toDouble();
    }

    // Parse reference point (centroid)
    LatLng? referencePoint;
    final refPoint = properties['referencePoint'];
    if (refPoint is Map && refPoint['coordinates'] is List) {
      final coords = refPoint['coordinates'] as List<dynamic>;
      if (coords.length >= 2) {
        referencePoint = LatLng(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        );
      }
    }

    // Parse polygon coordinates (WGS84 from WFS)
    List<LatLng> polygon = [];
    try {
      final geomType = geometry['type'] as String?;
      final coordinates = geometry['coordinates'] as List<dynamic>?;

      if (coordinates != null && coordinates.isNotEmpty) {
        List<dynamic> ring;

        if (geomType == 'MultiPolygon') {
          final firstPolygon = coordinates[0] as List<dynamic>;
          ring = firstPolygon[0] as List<dynamic>;
        } else if (geomType == 'Polygon') {
          ring = coordinates[0] as List<dynamic>;
        } else {
          ring = [];
        }

        if (ring.isNotEmpty) {
          polygon = ring.map((coord) {
            final c = coord as List<dynamic>;
            return LatLng(
              (c[1] as num).toDouble(), // lat
              (c[0] as num).toDouble(), // lng
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Error parsing WfsParcel geometry: $e');
    }

    final inspireId = properties['inspireId'] as Map<String, dynamic>?;

    return WfsParcel(
      localId: inspireId?['localId'] as String? ?? '',
      label: properties['label'] as String? ?? '',
      nationalCadastralReference: properties['nationalCadastralReference'] as String? ?? '',
      area: area,
      polygon: polygon,
      referencePoint: referencePoint,
    );
  }

  /// Get formatted area string
  String get formattedArea {
    if (area >= 10000) {
      return '${(area / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${area.toStringAsFixed(0)} m²';
    }
  }

  /// Get KO number from national cadastral reference (format: "KO_NUMBER PARCEL_NUMBER")
  String get koNumber {
    final parts = nationalCadastralReference.split(' ');
    return parts.isNotEmpty ? parts[0] : '';
  }

  /// Get parcel number from national cadastral reference
  String get parcelNumber {
    final parts = nationalCadastralReference.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : label;
  }

  /// Get display name for the parcel
  String get displayName => 'Parcela $label ($nationalCadastralReference)';
}

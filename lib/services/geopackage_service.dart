import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_geokit/flutter_geokit.dart';
import 'package:latlong2/latlong.dart';
import '../models/parcel.dart';
import '../models/map_location.dart';
import '../models/imported_overlay.dart';

/// Result of GeoPackage import operation
class GeoPackageImportResult {
  final String layerName;
  final List<Parcel> parcels;
  final List<MapLocation> locations;
  final List<ImportedOverlay> overlays;

  GeoPackageImportResult({
    required this.layerName,
    this.parcels = const [],
    this.locations = const [],
    this.overlays = const [],
  });

  int get totalCount => parcels.length + locations.length + overlays.length;

  double get totalArea => parcels.fold(0.0, (sum, p) => sum + p.areaM2);
}

/// Service for importing GeoPackage (.gpkg) files
class GeoPackageService {
  /// Import features from a GeoPackage file
  /// Imports all layers and features from the file
  static Future<GeoPackageImportResult> importFromGeoPackage(
    String filePath,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('GeoPackage file not found: $filePath');
    }

    final geoPackageHandler = GeoPackageHandler();
    final parcels = <Parcel>[];
    final locations = <MapLocation>[];
    final overlays = <ImportedOverlay>[];
    String layerName = 'Unknown';

    try {
      // Open GeoPackage file
      geoPackageHandler.openGeoPackage(filePath);

      // Read features from the file
      geoPackageHandler.readFeatures();

      // Get features
      final features = geoPackageHandler.features;

      if (features.isEmpty) {
        return GeoPackageImportResult(layerName: layerName);
      }

      // Use filename as layer name (all layers imported together)
      layerName = file.uri.pathSegments.last.replaceAll('.gpkg', '');

      // Process each feature
      for (var i = 0; i < features.length; i++) {
        final feature = features[i];
        final geometry = feature.geometry;

        if (geometry == null) continue;

        try {
          // Handle different geometry types
          if (geometry is GeoPoint) {
            // Import as MapLocation
            final location = _createLocationFromPoint(
              geometry,
              feature.properties,
              layerName,
              i + 1,
            );
            if (location != null) locations.add(location);
          } else if (geometry is GeoPolygon) {
            // Import as Parcel
            final parcel = _createParcelFromPolygon(
              geometry,
              feature.properties,
              layerName,
              i + 1,
            );
            if (parcel != null) parcels.add(parcel);
          } else if (geometry is GeoMultiPolygon) {
            // Import largest polygon as Parcel
            final parcel = _createParcelFromMultiPolygon(
              geometry,
              feature.properties,
              layerName,
              i + 1,
            );
            if (parcel != null) parcels.add(parcel);
          } else if (geometry is GeoLineString) {
            // Import as ImportedOverlay
            final overlay = _createOverlayFromLineString(
              geometry,
              feature.properties,
              layerName,
              i + 1,
            );
            if (overlay != null) overlays.add(overlay);
          } else if (geometry is GeoMultiLineString) {
            // Import as ImportedOverlay
            final overlay = _createOverlayFromMultiLineString(
              geometry,
              feature.properties,
              layerName,
              i + 1,
            );
            if (overlay != null) overlays.add(overlay);
          }
          // Note: Other geometry types (GeometryCollection, etc.) are skipped
        } catch (e) {
          print('Error processing feature $i: $e');
          continue;
        }
      }

      return GeoPackageImportResult(
        layerName: layerName,
        parcels: parcels,
        locations: locations,
        overlays: overlays,
      );
    } catch (e) {
      throw Exception('Failed to import GeoPackage: $e');
    } finally {
      try {
        geoPackageHandler.closeGeoPackage();
      } catch (e) {
        print('Warning: Failed to close GeoPackage: $e');
      }
    }
  }

  /// Create MapLocation from GeoPoint
  static MapLocation? _createLocationFromPoint(
    GeoPoint point,
    Map<String, dynamic> properties,
    String layerName,
    int featureIndex,
  ) {
    try {
      // GeoPoint has a LatLng point property
      final latLng = point.point;

      // Get name from properties or use default
      final name = properties['name']?.toString() ??
          properties['title']?.toString() ??
          'Point $featureIndex';

      return MapLocation(
        name: name,
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        type: LocationType.point,
      );
    } catch (e) {
      print('Error creating location from point: $e');
      return null;
    }
  }

  /// Create Parcel from GeoPolygon
  static Parcel? _createParcelFromPolygon(
    GeoPolygon polygon,
    Map<String, dynamic> properties,
    String layerName,
    int featureIndex,
  ) {
    try {
      // GeoPolygon has a List<LatLng> points property
      final coords = polygon.points;

      // Remove duplicate last point if present (GIS standard)
      final finalCoords = coords.toList();
      if (finalCoords.length >= 2 && finalCoords.first == finalCoords.last) {
        finalCoords.removeLast();
      }

      if (finalCoords.length < 3) return null; // Need at least 3 points

      // Get name from properties or use default
      final name = properties['name']?.toString() ??
          properties['title']?.toString() ??
          '$layerName - $featureIndex';

      // Get owner from properties if available
      final owner = properties['owner']?.toString() ??
          properties['vlastnik']?.toString();

      return Parcel(
        name: name,
        polygon: finalCoords,
        owner: owner,
        forestType: ForestType.mixed,
      );
    } catch (e) {
      print('Error creating parcel from polygon: $e');
      return null;
    }
  }

  /// Create Parcel from GeoMultiPolygon (use largest polygon)
  static Parcel? _createParcelFromMultiPolygon(
    GeoMultiPolygon multiPolygon,
    Map<String, dynamic> properties,
    String layerName,
    int featureIndex,
  ) {
    try {
      // GeoMultiPolygon has List<List<LatLng>> polygons property
      final polygons = multiPolygon.polygons;
      if (polygons.isEmpty) return null;

      // Find largest polygon by number of points
      List<LatLng>? largestPolygon;
      int maxPoints = 0;

      for (final polygon in polygons) {
        if (polygon.length > maxPoints) {
          maxPoints = polygon.length;
          largestPolygon = polygon;
        }
      }

      if (largestPolygon == null || largestPolygon.length < 3) return null;

      // Remove duplicate last point if present
      final finalCoords = largestPolygon.toList();
      if (finalCoords.length >= 2 && finalCoords.first == finalCoords.last) {
        finalCoords.removeLast();
      }

      if (finalCoords.length < 3) return null;

      final name = properties['name']?.toString() ??
          properties['title']?.toString() ??
          '$layerName - $featureIndex';

      final owner = properties['owner']?.toString() ??
          properties['vlastnik']?.toString();

      return Parcel(
        name: name,
        polygon: finalCoords,
        owner: owner,
        forestType: ForestType.mixed,
      );
    } catch (e) {
      print('Error creating parcel from multipolygon: $e');
      return null;
    }
  }

  /// Create ImportedOverlay from GeoLineString
  static ImportedOverlay? _createOverlayFromLineString(
    GeoLineString lineString,
    Map<String, dynamic> properties,
    String layerName,
    int featureIndex,
  ) {
    try {
      // GeoLineString has List<LatLng> points property
      final coords = lineString.points;
      if (coords.length < 2) return null; // Need at least 2 points

      // Get name from properties or use default
      final name = properties['name']?.toString() ??
          properties['title']?.toString() ??
          '$layerName - Line $featureIndex';

      // Create overlay
      final overlay = ImportedOverlay(
        name: name,
        layerName: layerName,
        geometryType: 'LineString',
        geometryJson: '', // Will be set by geometry setter
        visible: true,
      );

      // Set geometry (uses the setter which handles JSON encoding)
      overlay.geometry = [coords];

      // Store properties if available
      if (properties.isNotEmpty) {
        overlay.propertiesMap = properties;
      }

      return overlay;
    } catch (e) {
      print('Error creating overlay from linestring: $e');
      return null;
    }
  }

  /// Create ImportedOverlay from GeoMultiLineString
  static ImportedOverlay? _createOverlayFromMultiLineString(
    GeoMultiLineString multiLineString,
    Map<String, dynamic> properties,
    String layerName,
    int featureIndex,
  ) {
    try {
      // GeoMultiLineString has List<List<LatLng>> lineStrings property
      final allLines = multiLineString.lineStrings;
      if (allLines.isEmpty) return null;

      // Filter out lines with less than 2 points
      final validLines = allLines.where((line) => line.length >= 2).toList();
      if (validLines.isEmpty) return null;

      // Get name from properties or use default
      final name = properties['name']?.toString() ??
          properties['title']?.toString() ??
          '$layerName - MultiLine $featureIndex';

      // Create overlay
      final overlay = ImportedOverlay(
        name: name,
        layerName: layerName,
        geometryType: 'MultiLineString',
        geometryJson: '', // Will be set by geometry setter
        visible: true,
      );

      // Set geometry
      overlay.geometry = validLines;

      // Store properties if available
      if (properties.isNotEmpty) {
        overlay.propertiesMap = properties;
      }

      return overlay;
    } catch (e) {
      print('Error creating overlay from multilinestring: $e');
      return null;
    }
  }
}

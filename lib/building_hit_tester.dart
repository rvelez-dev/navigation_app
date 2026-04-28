import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart' as ll2;
import 'buildings.dart';

/// Handles loading building polygon data and answering "what building did
/// the user tap?" queries via ray-casting.
///
/// This class deliberately knows nothing about Flutter widgets, MapLibre,
/// or app state. It takes coordinates in, returns building names out.
class BuildingHitTester {
  // Internal storage of all loaded polygons.
  // Each entry: { 'name': String, 'geometry': Map<String, dynamic> }
  List<Map<String, dynamic>> _buildingPolygons = [];

  /// True once polygons are loaded and the tester is ready to answer queries.
  bool get isReady => _buildingPolygons.isNotEmpty;

  /// Number of polygons loaded — useful for debug output.
  int get polygonCount => _buildingPolygons.length;

  /// Loads all building polygons from the given asset paths.
  /// Call this once at app startup before using [findBuildingAt].
  Future<void> loadFromAssets(List<String> assetPaths) async {
    final List<Map<String, dynamic>> all = [];

    for (final path in assetPaths) {
      try {
        final String raw = await rootBundle.loadString(path);
        final Map<String, dynamic> fc = json.decode(raw);
        for (final feature in fc['features'] as List<dynamic>) {
          final name = feature['properties']['name'] as String?;
          if (name == null) continue;
          final resolvedName = _resolveBuildingName(name);
          if (resolvedName == null) continue;
          final geometry = feature['geometry'] as Map<String, dynamic>;
          all.add({'name': resolvedName, 'geometry': geometry});
        }
      } catch (e) {
        // Caller can log; we don't import debugPrint to stay Flutter-free.
        // ignore: avoid_print
        print('BuildingHitTester: error loading $path: $e');
      }
    }

    _buildingPolygons = all;
  }

  /// Returns the name of the building at [tapPoint], or null if none.
  String? findBuildingAt(ll2.LatLng tapPoint) {
    for (final building in _buildingPolygons) {
      final geometry = building['geometry'] as Map<String, dynamic>;
      final type = geometry['type'] as String;
      final coords = geometry['coordinates'] as List<dynamic>;

      // Both Polygon and MultiPolygon — check the outer ring of the first poly.
      final List<dynamic> rings =
          type == 'MultiPolygon' ? (coords[0] as List<dynamic>) : coords;
      final outerRing = rings[0] as List<dynamic>;

      if (_pointInPolygon(tapPoint, outerRing)) {
        return building['name'] as String;
      }
    }
    return null;
  }

  /// Ray-casting algorithm: returns true if [point] is inside [polygon].
  /// [polygon] is a list of [lng, lat] pairs (GeoJSON order).
  bool _pointInPolygon(ll2.LatLng point, List<dynamic> polygon) {
    final double px = point.longitude;
    final double py = point.latitude;
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final double xi = (polygon[i][0] as num).toDouble();
      final double yi = (polygon[i][1] as num).toDouble();
      final double xj = (polygon[j][0] as num).toDouble();
      final double yj = (polygon[j][1] as num).toDouble();

      final bool intersects = ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
      j = i;
    }
    return inside;
  }

  /// Maps a name from GeoJSON properties to a key in [buildingData].
  /// Tries exact, then case-insensitive, then partial match.
  String? _resolveBuildingName(String osmName) {
    if (buildingData.containsKey(osmName)) return osmName;

    final lower = osmName.toLowerCase();
    for (final key in buildingData.keys) {
      if (key.toLowerCase() == lower) return key;
    }
    for (final key in buildingData.keys) {
      if (lower.contains(key.toLowerCase()) ||
          key.toLowerCase().contains(lower)) {
        return key;
      }
    }
    return null;
  }
}

import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:dijkstra/dijkstra.dart';
import 'package:turf/turf.dart' as turf;

class RoutingService {
  // Our master graph: { "lat,lng": { "neighborLat,neighborLng": distanceInMeters } }
  Map<String, Map<String, int>> graph = {};

  // A list of all unique points in the graph to help us "snap" a user's click
  List<LatLng> allNodes = [];

  void loadGeoJson(String geoJsonString) {
    final data = jsonDecode(geoJsonString);
    final Distance distance = const Distance();

    for (var feature in data['features']) {
      var coords = feature['geometry']['coordinates'] as List;

      for (int i = 0; i < coords.length - 1; i++) {
        // SWAP: GeoJSON is [Lon, Lat], LatLng is (Lat, Lon)
        LatLng p1 = LatLng(coords[i][1].toDouble(), coords[i][0].toDouble());
        LatLng p2 = LatLng(coords[i+1][1].toDouble(), coords[i+1][0].toDouble());

        String id1 = "${p1.latitude},${p1.longitude}";
        String id2 = "${p2.latitude},${p2.longitude}";

        int dist = distance.as(LengthUnit.Meter, p1, p2).round();

        // Add to graph (bidirectional)
        graph.putIfAbsent(id1, () => {})[id2] = dist;
        graph.putIfAbsent(id2, () => {})[id1] = dist;

        // Store unique nodes for snapping later
        if (!allNodes.contains(p1)) allNodes.add(p1);
        if (!allNodes.contains(p2)) allNodes.add(p2);
      }
    }
  }

  // Find the closest point in our graph to where the user actually clicked
  LatLng _snapToGraph(LatLng point) {
    LatLng closest = allNodes.first;
    double minDistance = double.infinity;
    const Distance distance = Distance();

    for (var node in allNodes) {
      double d = distance.as(LengthUnit.Meter, point, node);
      if (d < minDistance) {
        minDistance = d;
        closest = node;
      }
    }
    return closest;
  }

  List<LatLng> getRoute(LatLng start, LatLng end) {
    // 1. Snap user clicks to the nearest walkway point
    LatLng snappedStart = _snapToGraph(start);
    LatLng snappedEnd = _snapToGraph(end);

    // 2. Run Dijkstra
    List dynamicPath = Dijkstra.findPathFromGraph(
        graph,
        "${snappedStart.latitude},${snappedStart.longitude}",
        "${snappedEnd.latitude},${snappedEnd.longitude}"
    );

    // 3. Convert String IDs back to LatLng objects for the map
    return dynamicPath.map((s) {
      var parts = s.split(',');
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    }).toList();
  }
}
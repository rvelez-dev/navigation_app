import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:dijkstra/dijkstra.dart';

class RoutingService {
  // Our master graph: { "lat,lng": { "neighborLat,neighborLng": distanceInMeters } }
  Map<String, Map<String, int>> graph = {};

  // A list of all unique points in the graph to help us "snap" a user's click
  // when user taps on a map, we find the nearest point
  List<LatLng> allNodes = [];

  //routing cache -> helps store complete routes to avoid re-running Dijkstra's algorithm
  final Map<String,List<LatLng>> _routeCache ={};
  static const int _maxCacheSize = 100; // keep last 100 routes in memory

  // snap cache -> stores the nearest graph node for tapped locations to avoid relooping through all nodes
  final Map<String,LatLng> _snapCache = {};

  //Loads GeoJSON file containing campus walkways and builds the routing graph
  void loadGeoJson(String geoJsonString) {
    //parsing the JSON string into a dart map
    final data = jsonDecode(geoJsonString);

    //distance calculator (used to measure walkaway segment lengths)
    final Distance distance = const Distance();

    //extracting all the walkway features
    final features = data['features'] as List;

    //looping through each walkway feature
    for (var feature in features) {
      //receiving coordinates
      var coords = feature['geometry']['coordinates'] as List;

      //processing each segment of the walkway
      for (int i = 0; i < coords.length - 1; i++) {
        //GeoJSOn stores coordinates as [Long,Lat]
        // SWAP: GeoJSON is [Lon, Lat], LatLng is (Lat, Lon)
        LatLng p1 = LatLng(coords[i][1].toDouble(), coords[i][0].toDouble());
        LatLng p2 = LatLng(coords[i+1][1].toDouble(), coords[i+1][0].toDouble());

        //creating string IDs for these points (used as keys in the graph)
        String id1 = "${p1.latitude},${p1.longitude}";
        String id2 = "${p2.latitude},${p2.longitude}";

        //calculating walking distance between these two points in meters 
        int dist = distance.as(LengthUnit.Meter, p1, p2).round();

        // Add to graph (bidirectional)
        graph.putIfAbsent(id1, () => {})[id2] = dist;
        graph.putIfAbsent(id2, () => {})[id1] = dist;

        // Store unique nodes for snapping later
        if (!allNodes.contains(p1)) allNodes.add(p1);
        if (!allNodes.contains(p2)) allNodes.add(p2);
      }
    }
    //log the results to verify the graph loaded correctly 
    debugPrint("Graph loaded: ${graph.length} nodes, ${allNodes.length} unique points");
  }

  // Find the closest point in our graph to where the user actually clicked
  //using cache because it gets called for every route function
  LatLng _snapToGraph(LatLng point) {
    //creating cache key by rounding coordinates to 6th decimal place
    final cacheKey = '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

    //cache check of if we checked location before
    if(_snapCache.containsKey(cacheKey)){
      //if yes return cached result instantly
      return _snapCache[cacheKey]!;
    }
    //making sure we have nodes to search
    if(allNodes.isEmpty){
      debugPrint("No nodes loaded into graph!");
    }

    //initializing search variables
    LatLng closest = allNodes.first;
    double minDistance = double.infinity;
    const Distance distance = Distance();

    //looping through every walkway node to find the nearest one
    for (var node in allNodes) {
      //calculating distance from tapped point to this node
      double d = distance.as(LengthUnit.Meter, point, node);
      //if the node is closer than minimal distance calculated
      if (d < minDistance) {
        //update
        minDistance = d;
        closest = node;

        //early exit if we found a distance within one meter
        //helps prevent unnecessary distance calculations
        if(d < 1.0) break;
      }
    }
    //caching the result to store it so we don't have to search again
    //Implement simple cache size limit to prevent memory bloat
    if (_snapCache.length >= _maxCacheSize){
      //remove the oldest entry (first one added)
      _snapCache.remove(_snapCache.keys.first);
    }
    _snapCache[cacheKey] = closest;

    //caching result so we don't have to search again 
    return closest;
  }

  //calculates the shortest walking route between two points
  List<LatLng> getRoute(LatLng start, LatLng end) {
    // rounding coordinates to 6 decimal places for cache consistency
    final startKey = '${start.latitude.toStringAsFixed(6)},${start.longitude.toStringAsFixed(6)}';
    final endKey = '${end.latitude.toStringAsFixed(6)},${end.longitude.toStringAsFixed(6)}';
    final cacheKey = '$startKey - $endKey';

    //checking route cache
    if(_routeCache.containsKey(cacheKey)){
      debugPrint("Route cache hit! Returning instant route.");
      return _routeCache[cacheKey]!;
    }
    //displaying cache miss debug print
    debugPrint("Cache miss - calculating new route ");

    // 1. Snap user clicks to the nearest walkway point
    LatLng snappedStart = _snapToGraph(start);
    LatLng snappedEnd = _snapToGraph(end);

    //If both points snap to same location no need to route
    if(snappedStart.latitude == snappedEnd.latitude && snappedStart.longitude == snappedEnd.longitude){
      debugPrint("Start and end are the same point - no routing needed");
      return [snappedStart];
    }

    try {
      // 2. Run Dijkstra
      List dynamicPath = Dijkstra.findPathFromGraph(
          graph,
          "${snappedStart.latitude},${snappedStart.longitude}",
          "${snappedEnd.latitude},${snappedEnd.longitude}"
      );

      // 3. Convert String IDs back to LatLng objects for the map
        final route = dynamicPath.map((s) {
        var parts = s.split(',');
        return LatLng(double.parse(parts[0]), double.parse(parts[1]));
        }).toList();

        //store in cache so next time this route is instant
        //Implement LRU (Least recently used) eviction by removing oldest entry
        if(_routeCache.length >= _maxCacheSize){
          _routeCache.remove(_routeCache.keys.first);
        }
        _routeCache[cacheKey] = route;

        debugPrint("Route calculated and cached :${route.length} points");
        return route;

    }catch(e){
      debugPrint("Error calculating route: $e");
      return [];
    }
  }
  //WHEN TO CALL THIS:
  //After reloading GeoJSON data
  //When testing to verify cache is working
  //If routes seem wrong (stale cached data)
  void clearCache(){
    _routeCache.clear();
    _snapCache.clear();
    debugPrint("Route and snap caches cleared");
  }

  //returns statistics about cache usage for debugging
  Map<String, int> getCacheStats(){
    return{
      'routeCacheSize': _routeCache.length,
      'snapCacheSize': _snapCache.length,
      'graphNodes': graph.length,
      'allNodesCount': allNodes.length,
    };
  }
}
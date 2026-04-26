import 'dart:math';
import 'package:latlong2/latlong.dart' as ll2;
import 'campus_dropdown.dart'; // calling dropdown class
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:flutter/services.dart' show rootBundle; // Required to load the file
import 'routing_service.dart'; // Ensure this file exists in your lib folder
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:async';
// Required for Uint8List
import 'package:flutter/foundation.dart'; // for compute()
import 'dart:convert';
import 'building_info.dart';
import 'buildings.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  // Create the instance for routing algorithm
  final RoutingService _routingService = RoutingService();

  //hosts the map platform and the layers within it
  MapLibreMapController? mapController;

  // State variables to track navigation
  ll2.LatLng? _startPoint;
  ll2.LatLng? _endPoint;
  List<ll2.LatLng> _routePolyline = [];
  bool _isGraphLoaded = false;

  //state variable for time of distance
  String _walkingTimeEstimate = "";

  bool _showBlueDot = false;
  bool _autoCenter = true;
  ll2.LatLng? _currentUserLocation;

  String? _selectedDestinationName;
  bool _isRouting = false;
  //popup menu for building info, starting route,see walking time estimate etc.
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  //location package
  final Location _location = Location();

  //holds all the 2d polygons from building geojson files
  List<Map<String, dynamic>> _buildingPolygons = [];

  //Debounce timers to prevent excessive setState calls
  Timer? _locationUpdateTimer;
  Timer? _routeUpdateTimer;
  Timer? _rerouteTimer;
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isAddingRoute = false;

  //manage route animated display
  Timer?  _animationTimer;
  double  _dashOffset = 0;
  bool    _routeLayerExists = false;

  //track the finger position
  Offset? _pointerDownPosition;
  //time tracking to catch drags
  DateTime? _pointerDownTime;

  //puts directional labels over designated buildings
  static const Map<String,dynamic> _buildingLabelsData = {
    "type": "FeatureCollection",
    "features": [
      { "type": "Feature", "properties": { "name": "Eiler-Martin Stadium" }, "geometry": { "type": "Point", "coordinates": [-75.1727, 40.9936] } },
      { "type": "Feature", "properties": { "name": "Dansbury Commons" }, "geometry": { "type": "Point", "coordinates": [-75.1736, 40.9970] } },
      { "type": "Feature", "properties": { "name": "Flagler-Metzgar Center" }, "geometry": { "type": "Point", "coordinates": [-75.1729, 40.9970] } },
      { "type": "Feature", "properties": { "name": "Monroe Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1727, 40.9951] } },
      { "type": "Feature", "properties": { "name": "Koehler Fieldhouse and Natatorium" }, "geometry": { "type": "Point", "coordinates": [-75.1703, 40.9968] } },
      { "type": "Feature", "properties": { "name": "Kemp Library" }, "geometry": { "type": "Point", "coordinates": [-75.1701, 40.9984] } },
      { "type": "Feature", "properties": { "name": "Mattioli Recreation Center" }, "geometry": { "type": "Point", "coordinates": [-75.1701, 40.9953] } },
      { "type": "Feature", "properties": { "name": "Beers Lecture Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1749, 40.9955] } },
      { "type": "Feature", "properties": { "name": "Reibman Administration Building" }, "geometry": { "type": "Point", "coordinates": [-75.1768, 40.9957] } },
      { "type": "Feature", "properties": { "name": "Moore Biology Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1749, 40.9965] } },
      { "type": "Feature", "properties": { "name": "Gessner" }, "geometry": { "type": "Point", "coordinates": [-75.1751, 40.9958] } },
      { "type": "Feature", "properties": { "name": "Sci-Tech Center" }, "geometry": { "type": "Point", "coordinates": [-75.1758, 40.9965] } },
      { "type": "Feature", "properties": { "name": "Stroud Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1741, 40.99545] } },
      { "type": "Feature", "properties": { "name": "University Center"} , "geometry": { "type": "Point", "coordinates": [-75.1738, 40.9961] } },
      { "type": "Feature", "properties": { "name": "University Center (soon)"} , "geometry": { "type": "Point", "coordinates": [-75.17363, 40.99553] } },
      { "type": "Feature", "properties": { "name": "Laurel Residence Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1730, 40.9961] } },
      { "type": "Feature", "properties": { "name": "Shawnee Residence Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1720, 40.9960] } },
      { "type": "Feature", "properties": { "name": "Minsi Residence Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1718, 40.9954] } },
      { "type": "Feature", "properties": { "name": "Linden Residence Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1711, 40.9961] } },
      { "type": "Feature", "properties": { "name": "Hemlock Suites" }, "geometry": { "type": "Point", "coordinates": [-75.1713, 40.9978] } },
      { "type": "Feature", "properties": { "name": "Lenape Residence Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1720, 40.9986] } },
      { "type": "Feature", "properties": { "name": "Hawthorn Suites" }, "geometry": { "type": "Point", "coordinates": [-75.1727, 40.9991] } },
      { "type": "Feature", "properties": { "name": "Sycamore Suites" }, "geometry": { "type": "Point", "coordinates": [-75.1722, 40.9974] } },
      { "type": "Feature", "properties": { "name": "Abeloff" }, "geometry": { "type": "Point", "coordinates": [-75.175136, 40.994328] } },
      { "type": "Feature", "properties": { "name": "Wess 90.3 Radio" }, "geometry": { "type": "Point", "coordinates": [-75.1738, 40.9949] } },
      { "type": "Feature", "properties": { "name": "Zimbar-Liljenstein Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1735, 40.9938] } },
      { "type": "Feature", "properties": { "name": "Rosenkrans" }, "geometry": { "type": "Point", "coordinates": [-75.174627, 40.994553] } },
      { "type": "Feature", "properties": { "name": "DeNike" }, "geometry": { "type": "Point", "coordinates": [-75.17602, 40.994049] } },
      { "type": "Feature", "properties": { "name": "Innovation Center" }, "geometry": { "type": "Point", "coordinates": [-75.1783, 40.9946] } },
      { "type": "Feature", "properties": { "name": "Facilities Management" }, "geometry": { "type": "Point", "coordinates": [-75.1768, 40.9975] } },
      { "type": "Feature", "properties": { "name": "University Ridge" }, "geometry": { "type": "Point", "coordinates": [-75.1834, 40.9900] } },
      { "type": "Feature", "properties": { "name": "Fine and Performing Arts" }, "geometry": { "type": "Point", "coordinates": [-75.166295, 40.998738] } }
    ]
  };

  @override
  void initState() {
    super.initState();
    _initializeAsync();

  }

  @override
  void dispose(){
    //clean up timers and subscriptions
    _locationUpdateTimer?.cancel();
    _routeUpdateTimer?.cancel();
    _locationSubscription?.cancel();
    _animationTimer?.cancel();
    _rerouteTimer?.cancel();
    super.dispose();
  }

  //async method
  Future<void> _initializeAsync() async {
    //starting both operations concurrently instead of sequentially
    await Future.wait([
      _initializeRouting(),
      _requestLocationPermissionAndCenter(),
      _loadBuildingPolygons(),
    ]);
  }

  // 2. Load the GeoJSON file into the service
  Future<void> _initializeRouting() async {
    try {
      final String geoJsonData = await rootBundle.loadString(
          'assets/esu_jsons/walkways.geojson');
      _routingService.loadGeoJson(geoJsonData);

      if(mounted) {
        setState(() {
          _isGraphLoaded = true;
        });
      }
      debugPrint("graph loaded successfully");
    } catch (e) {
      debugPrint("Error loading GeoJSON: $e");
    }
  }

  // requesting location permission and move map to current location
  Future<void> _requestLocationPermissionAndCenter() async{
    //check if hardware has location enabled
    bool serviceEnabled = await _location.serviceEnabled();
    if(!serviceEnabled){
      serviceEnabled = await _location.requestService();
      if(!serviceEnabled) return;
    }
    //request permission to use location data
    PermissionStatus permissionGranted = await _location.hasPermission();
    if(permissionGranted == PermissionStatus.denied){
      permissionGranted = await _location.requestPermission();
      if(permissionGranted != PermissionStatus.granted)return; //if no permissions stop
    }

    //manually setting up recurring checks on location every 1.5 seconds
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      //reducing update frequency from 1.5s to 3s to reduce setState calls
      interval: 3000, // Update every 3 seconds
      distanceFilter: 5, //only update if moved 5 meters (can change back to zero if needed)

    );

    //Getting current location and move map accordingly
    final LocationData userLocation = await _location.getLocation();
    if(userLocation.latitude !=null && userLocation.longitude != null){
      if(mounted) {
        setState(() {
          // SAVE the location to your variable here!
          _currentUserLocation =
              ll2.LatLng(userLocation.latitude!, userLocation.longitude!);
        });
      }

      //initial lock on to user location
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(userLocation.latitude!, userLocation.longitude!),
            mapController?.cameraPosition?.zoom ?? 17.0,
        ),
      );
    }

    //debounce location updates to prevent excessive setState calls
    _locationSubscription = _location.onLocationChanged.listen((LocationData newLoc){
      if(newLoc.latitude != null && newLoc.longitude != null) {
        _handleLocationUpdate(newLoc);
      }
    });
  }

  //debounced location update handler
  void _handleLocationUpdate(LocationData newLoc){
    //cancel existing timer
    _locationUpdateTimer?.cancel();

    //Update location immediately (no setState yet)
    _currentUserLocation = ll2.LatLng(newLoc.latitude!,newLoc.longitude!);

    //Batch UI updates - only call setState every 500ms max
    _locationUpdateTimer = Timer(const Duration(milliseconds: 500), (){
      if(!mounted) return;

      bool needsUpdate = true;
      _startPoint = _currentUserLocation;

      //debounce route recalculation
      if(_endPoint != null){
        _scheduleRouteUpdate();
      }

      if(_autoCenter){
        mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(newLoc.latitude!, newLoc.longitude!),
              mapController?.cameraPosition?.zoom ?? 17.0,
            ),
        );
      }
      //Only call setState if something changed
      if(needsUpdate && mounted){
        setState(() {});
      }
    });
  }

  //method to debounce route recalculation
  void _scheduleRouteUpdate(){
    _routeUpdateTimer?.cancel();
    //every 10 seconds recalculate route
    _routeUpdateTimer = Timer(const Duration(milliseconds: 1000), (){
      if(_startPoint != null && _endPoint != null && mounted){
        final newRoute = _routingService.getRoute(_startPoint!, _endPoint!);
        if(mounted){
          setState(() {
            _routePolyline = newRoute;
          });
          _updateRouteGeometry(_routePolyline);
        }
      }
    });
  }

  void _startRerouteTimer() {
    _rerouteTimer?.cancel();
    _rerouteTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isRouting) {
        debugPrint("reroute timer, not rerouting. is routing or not using current location");
        return;
      }
      if (_currentUserLocation == null || _endPoint == null) {
        debugPrint("reroute timer, current location or end point is null, {userloc: $_currentUserLocation} {endpoint: $_endPoint}");
        return;
      }
      _startPoint = _currentUserLocation;
      _makePath(_startPoint!, _endPoint!);
      debugPrint("Reroute tick — redrawing from current location: $_currentUserLocation to $_endPoint");
    });
  }

  void _stopRerouteTimer() {
    _rerouteTimer?.cancel();
    _rerouteTimer = null;
  }

  //returns walking distance
  String _getWalkingTimeEstimate(List<ll2.LatLng> route) {
    if (route.isEmpty || route.length < 2) return "";

    final ll2.Distance distCalc = const ll2.Distance();
    double totalMeters = 0;

    for (int i = 0; i < route.length - 1; i++) {
      totalMeters += distCalc.as(
        ll2.LengthUnit.Meter,
        route[i],
        route[i + 1],
      );
    }

    // Average walking speed: 1.4 m/s (~5 km/h)
    final int seconds = (totalMeters / 1.4).round();
    final int minutes = (seconds / 60).ceil();

    if (minutes < 1) return "< 1 min walk";
    return "~$minutes min walk • ${(totalMeters).round()} m";
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false; // User refused to turn on GPS hardware
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false; // User denied app permission
    }

    // If the user permanently denied permission, this will return false
    if (permissionGranted == PermissionStatus.deniedForever) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              "Location permission is permanently denied. Please enable it in settings.")),
        );
      }
      return false;
    }

    return true;
  }

// Ray casting algorithm — returns true if [point] is inside [polygon]
// polygon is a list of [lng, lat] pairs (GeoJSON order)
  bool _pointInPolygon(ll2.LatLng point, List<dynamic> polygon) {
    final double px = point.longitude;
    final double py = point.latitude;
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final double xi = (polygon[i][0] as num).toDouble(); // lng
      final double yi = (polygon[i][1] as num).toDouble(); // lat
      final double xj = (polygon[j][0] as num).toDouble();
      final double yj = (polygon[j][1] as num).toDouble();

      final bool intersects = ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
      j = i;
    }
    debugPrint("Debug (_pointInPolygon): inside: $inside");
    return inside;
  }

  String? _findTappedBuilding(ll2.LatLng tapPoint) {
    debugPrint("Debug (_findTappedBuilding): Finding tapped building");
    for (final building in _buildingPolygons) {
      final geometry = building['geometry'] as Map<String, dynamic>;
      final type = geometry['type'] as String;
      final coords = geometry['coordinates'] as List<dynamic>;

      // Both Polygon and MultiPolygon — check each ring
      final List<dynamic> rings = type == 'MultiPolygon'
          ? (coords[0] as List<dynamic>) // first polygon of multipolygon
          : coords;

      final outerRing = rings[0] as List<dynamic>;
      if (_pointInPolygon(tapPoint, outerRing)) {
        debugPrint('Tapped inside: ${building['name']}');
        debugPrint("Debug (_findTappedBuilding): tapped building: ${building['name']}");
        return building['name'] as String;
      }
    }
    debugPrint("Debug (_findTappedBuilding): Found nothing :| ");
    return null;
  }

  //bearing to change camera angle towards location
  void _tiltAndRotateCamera(ll2.LatLng start, ll2.LatLng destination) {
    if (mapController == null) return;

    final ll2.Distance distance = const ll2.Distance();
    double bearing = distance.bearing(start, destination);


    // Animates the camera to tilt and face the destination
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(start.latitude, start.longitude), // Keep user at center/bottom
          tilt: 60.0,      // Tilts the map to see those 3D buildings
          zoom: 17.5,      // Slightly zoom in for a "navigation" feel
          bearing: bearing, // Rotates map to face the destination
        ),
      ),
      duration: const Duration(milliseconds: 1500),
    );
  }

  //loads in building polygon data form geojsons
  Future<void> _loadBuildingPolygons() async {
    final List<Map<String, dynamic>> all = [];

    for (final path in [
      'assets/esu_jsons/campusbuildings.geojson',
      'assets/esu_jsons/apartments.geojson',
      'assets/esu_jsons/dorms.geojson',
    ]) {
      try {
        final String raw = await rootBundle.loadString(path);
        final Map<String, dynamic> fc = json.decode(raw);
        for (final feature in fc['features'] as List<dynamic>) {
          final name = feature['properties']['name'] as String?;
          if (name == null) continue;
          // Resolve the name to the exact buildingData key
          final resolvedName = _resolveBuildingName(name);
          if (resolvedName == null) continue;
          final geometry = feature['geometry'] as Map<String, dynamic>;
          all.add({'name': resolvedName, 'geometry': geometry});
        }
        debugPrint('Loaded ${fc['features'].length} features from $path');
      } catch (e) {
        debugPrint('Error loading $path: $e');
      }
    }

    setState(() => _buildingPolygons = all);
    debugPrint('Loaded ${all.length} building polygons');
  }

  //helps to make matches between data
  String? _resolveBuildingName(String osmName) {
    // Exact match first
    if (buildingData.containsKey(osmName)) return osmName;
    // Case-insensitive fallback
    final lower = osmName.toLowerCase();
    for (final key in buildingData.keys) {
      if (key.toLowerCase() == lower) return key;
    }
    // Partial match — OSM name contains your key or vice versa
    for (final key in buildingData.keys) {
      if (lower.contains(key.toLowerCase()) || key.toLowerCase().contains(lower)) {
        debugPrint('Debug(_resolveBuildingName): Matched $osmName to $key');
        return key;
      }
    }
    debugPrint('Debug(_resolveBuildingName): No buildingData match for OSM name: "$osmName"');
    return null;
  }

  //puts 3d buildings on map
  ///NOTE: need to remove demolished computing center from map
  Future <void> _add3DBuildingsLayer() async {
    // Check if the controller is ready
    if (mapController == null) return;

    // Attempt to remove it first in case it partially loaded during a hot reload
    try { await mapController!.removeLayer("3d-buildings"); } catch (e) {}

    // This adds the 3D extrusion layer to the map style
    try {
      await mapController!.addLayer(
        "openmaptiles",
        // This is the standard source layer name in OpenFreeMap tiles
        "3d-buildings", // A unique ID we give to this new 3D layer
        FillExtrusionLayerProperties(
          // Color of the buildings
          fillExtrusionColor: '#F0EBE1',
          // 'render_height' is the property in OSM data that tells us how tall it is
          fillExtrusionHeight: ["*", ["get", "render_height"], 1.5],
          fillExtrusionBase: ["get", "render_min_height"],
          fillExtrusionOpacity: 0.9,
          //add vertical shading to buildings
          fillExtrusionVerticalGradient: true,
        ),
        //belowLayerId: firstSymbolId,
        sourceLayer: "building",
        //attempt to filter out computing center
        //filter: ["!=", ["get","osm_id"], "w554578874"],
      );
      debugPrint("3D buildings layer added successfully");
    }catch (e){
      debugPrint("Error adding 3D buildings layer: $e");
    }
  }


  Future<void> _addLabelsLayer() async {
    if (mapController == null) return;

    try {
      await mapController!.addSource(
        "building-labels-source",
        GeojsonSourceProperties(data: _buildingLabelsData),
      );

      await mapController!.addSymbolLayer(
        "building-labels-source",               // sourceId
        "building-labels-display-layer",        // layerId
        SymbolLayerProperties(
          textField: ["get", "name"],
          textColor: "#333333",
          // "Open Sans Bold" is crisper than Regular.
          // If it fails to load, it will fall back to the map's default.
          textFont: ["Noto Sans Regular"],
          textTransform: "uppercase", // Makes it look like an official blueprint
          textLetterSpacing: 0.1,
          textSize: [
            "interpolate",
            ["linear"],
            ["zoom"],
            15, 10.0,
            18, 14.0
          ],
          // A white outline ensures text is readable on top of grey buildings
          textHaloColor: "#FFFFFF",
          textHaloWidth: 1.5,
          textHaloBlur: 0.5, // Softens the edge of the halo
          //icons idea
          // iconImage: "info_icon",
          // iconSize: 0.05,
          // iconAnchor: "bottom",
          // iconOffset: [0, -10], // Push it up slightly above the anchor
          // textOffset: [0, 1], // Push text down below the icon
          textAllowOverlap: true,
        ),
      );

      debugPrint("Building labels layer added successfully");
    } catch (e) {
      debugPrint("error in _addLabelsLayer: $e");
    }
  }

  //adding grass layer to app
  Future <void> _addGrassLayer() async {
    if(mapController == null ) return;

    try{

      //loading grass geojson
      final String grassJSON = await rootBundle.loadString(
        'assets/esu_jsons/grass.geojson',
      );
      debugPrint("Grass GeoJson preview: ${grassJSON.substring(0,100)}");
      //register the geoJSON data as a source with mapLibre
      //convert json string data into map so maplibre understands it
      final Map<String, dynamic> grassData = json.decode(grassJSON); // now a real Map
      await mapController!.addSource("grass-source", GeojsonSourceProperties(data: grassData));
      //confirm source was registered
      final sources = await mapController!.getSourceIds();
      debugPrint("All sources after adding grass: $sources");

      //drawing layer
      await mapController!.addFillLayer(
          "grass-source",
          "grass-layer",
      const FillLayerProperties(
        fillColor: "#BEE7A5",
        fillOpacity: 0.5,
      ),
        //adding below all layers
        belowLayerId: "building",
      );
      final layers = await mapController!.getLayerIds();
      //debugPrint("all layers after adding grass: $layers");
      //debugPrint("full layer list: $layers");
      //debugPrint("Grass GeoJSON preview: ${grassJSON.substring(0, 300)}");
      debugPrint("Grass layer added successfully");
    }catch (e){
      debugPrint("Error adding grass later: $e");
    }
  }

  //adding trees to the map
  Future<void> _addTreeLayer() async {
    if (mapController == null) return;

    try {
      final String canopyJson = await rootBundle.loadString(
        'assets/esu_jsons/trees.geojson',
      );
      final String trunkJson = await rootBundle.loadString(
        'assets/esu_jsons/treetrunks.geojson',
      );
      final Map<String, dynamic> canopyData = json.decode(canopyJson);
      final Map<String, dynamic> trunkData = json.decode(trunkJson);

      await mapController!.addSource(
        "tree-canopy-source",
        GeojsonSourceProperties(data: canopyData),
      );

      await mapController!.addSource(
        "tree-trunk-source",
        GeojsonSourceProperties(data:trunkData),
      );

      // Canopy layer
      await mapController!.addLayer(
        "tree-canopy-source",
        "tree-canopy-layer",
        FillExtrusionLayerProperties(
          fillExtrusionColor: "#77a37a",
          fillExtrusionHeight: 6.25,
          fillExtrusionBase: 2.5,
          fillExtrusionOpacity: 0.95,
          fillExtrusionVerticalGradient: true,
        ),
        belowLayerId: "building-labels-display-layer",
      );

      // trunk layer
      await mapController!.addLayer(
        "tree-trunk-source",
        "tree-trunk-layer",
        FillExtrusionLayerProperties(
          fillExtrusionColor: "#3B1F0A",
          fillExtrusionHeight: 3.5,
          fillExtrusionBase: 0.0,
          fillExtrusionOpacity: 0.95,
          fillExtrusionVerticalGradient: true,
        ),
        belowLayerId: "building-labels-display-layer",
      );

      debugPrint("Tree layers added successfully");
    } catch (e) {
      debugPrint("Error adding tree layer: $e");
    }
  }

  //Creates the route points argument for draw route using a given start and end, calls _addRouteLayer
  void _makePath(ll2.LatLng start, ll2.LatLng end){
    debugPrint("Debug: Calling routing service");
    final path = _routingService.getRoute(start, end);

    if(mounted){
      setState(() {
        _routePolyline = path;
        _walkingTimeEstimate = _getWalkingTimeEstimate(path);
      });
    }
    //addRouteLayer(_routePolyline);//replacing call with _updateRouteGeometry
    _updateRouteGeometry(_routePolyline);

    //print all point in the path
    /*print("Path points: ");
    for(int i = 0; i < path.length; i++){
      print(path[i]);
    }*/
  }

  // This actually talks to the MapLibre engine to visualize the path from _makePath
  Future<void> addRouteLayer(List<ll2.LatLng> points) async {
    if (mapController == null || points.isEmpty) return;
    if(_isAddingRoute){return;}
    _isAddingRoute = true;

    // Stop any animation that was running for a previous route
    _stopRouteAnimation();

    try { await mapController!.removeLayer("animated-route"); } catch (e) {debugPrint("addRouteLayer: Error removing animated-route layer: $e");}
    try { await mapController!.removeLayer("route-layer"); } catch (e) {debugPrint("addRouteLayer: Error removing route-layer layer: $e");}
    try { await mapController!.removeSource("route-source"); } catch (e) {debugPrint("addRouteLayer: Error removing route-source layer: $e");}
    await mapController!.clearLines();

    // Convert your LatLng list into a GeoJSON LineString feature.
    // GeoJSON wants [longitude, latitude] — the opposite of how you store them!
    final List<List<double>> coords = points
        .map((p) => [p.longitude, p.latitude])
        .toList();

    final Map<String, dynamic> geojson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": coords,
          }
        }
      ]
    };

    try {
      // Remove old layer/source if they exist
      // We track _routeLayerExists ourselves because querying the map is async
      // and can race with the add calls below.
      if (_routeLayerExists) {
        try { await mapController!.removeLayer("animated-route"); } catch (_) {}
        try { await mapController!.removeSource("route-source"); } catch (_) {}
        _routeLayerExists = false;
      }

      // Also clear any old addLine() lines from the previous static approach
      await mapController!.clearLines();

      //Add the GeoJSON source
      // A "source" is just the data. A "layer" is how it looks.
      // Separating them lets us update the style (dasharray) without
      // touching the geometry data.
      await mapController!.addSource(
        "route-source",
        GeojsonSourceProperties(data: geojson),
      );

      // Add the line layer
      // lineDasharray: [dash length, gap length] in "line-width units"
      // We start with [2, 2] — equal dashes and gaps — and shift these
      // values in the timer to create motion.
      await mapController!.addLayer(
        "route-source",
        "animated-route",
        LineLayerProperties(
          lineColor: "#FF0000",
          lineWidth: 5.0,
          lineOpacity: 0.9,
          lineCap: "round",           // rounded ends on each dash segment
          lineJoin: "round",
          lineDasharray: [2, 2],      // initial dash pattern that gets animated
        ),
      );

      _routeLayerExists = true;

      //Start the animation loop
      _startRouteAnimation();

    } catch (e) {
      debugPrint("Caught map error in addRouteLayer: $e");
    }
    finally {
      _isAddingRoute = false;
    }
  }

  void _startRouteAnimation() {
    // Each tick shifts the dash pattern by 0.5 units.
    // The pattern repeats every (dash + gap) = 4 units, so the "loop"
    // completes every 8 ticks (400 ms) — a comfortable walking-pace feel.
    // make it faster: increase the step (e.g. 1.0) or shorten the interval.
    // make it slower: decrease the step (e.g. 0.25) or lengthen the interval.
    _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || mapController == null || !_routeLayerExists) return;

      _dashOffset = (_dashOffset + 0.5) % 4.0; // wrap at (dash+gap) total
      // so the dash appears to march continuously along the path.
      final double t = _dashOffset;
      mapController!.setLayerProperties(
        "animated-route",
        LineLayerProperties(
          lineDasharray: [t, 4.0 - t, 2.0, 2.0],
        ),
      );
    });
  }

  void _stopRouteAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
    // Note: we don't reset _dashOffset here so that if the route is
    // redrawn it picks up smoothly rather than jumping back to 0.
  }

  Future<void> _startRouting() async {
    // 1. If we don't have a location yet, request permissions and get one
    if (_currentUserLocation == null) {
      bool hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required to start navigation.")),
        );
        return;
      }

      // Permission granted — now fetch location and start listening
      try {
        final LocationData freshLoc = await _location.getLocation()
            .timeout(const Duration(seconds: 5));
        if (freshLoc.latitude != null && freshLoc.longitude != null) {
          _currentUserLocation = ll2.LatLng(freshLoc.latitude!, freshLoc.longitude!);

          // Also start the listener if it's not running
          _locationSubscription ??= _location.onLocationChanged.listen((LocationData newLoc) {
            if (newLoc.latitude != null && newLoc.longitude != null) {
              _handleLocationUpdate(newLoc);
            }
          });
        }
      } catch (e) {
        debugPrint("Failed to get location: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not get your location. Please try again.")),
        );
        return;
      }
    }

    // 2. Now set the start point
    _startPoint = _currentUserLocation;

    if (_startPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Still waiting for GPS signal...")),
      );
      return;
    }

    // 3. Update state to show we are navigating
    setState(() {
      _isRouting = true;
    });

    // 4. Draw the path and move the camera
    _makePath(_startPoint!, _endPoint!);
    _tiltAndRotateCamera(_startPoint!, _endPoint!);

    // 5. Shrink the pull-up menu down to 15% of the screen
    _sheetController.animateTo(
      0.15,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _startRerouteTimer();
  }

  Future<void> _updateRouteGeometry(List<ll2.LatLng> points) async {
    if (mapController == null || points.isEmpty) return;

    final List<List<double>> coords = points
        .map((p) => [p.longitude, p.latitude])
        .toList();

    final Map<String, dynamic> geojson = {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": coords,
        }
      }]
    };

    try {
      if (_routeLayerExists) {
        // Just swap the data — layer and animation keep running untouched
        await mapController!.setGeoJsonSource("route-source", geojson);
      } else {
        // First time, do the full build
        await addRouteLayer(points);
      }
    } catch (e) {
      debugPrint("Error updating route geometry: $e");
    }
  }

  Future<void> _addDestinationMarker(ll2.LatLng location) async {
    if (mapController == null) return;

    // Remove layer (must happen before removing source)
    try {
      final layers = await mapController!.getLayerIds();
      if (layers.contains("destination-pin")) {
        await mapController!.removeLayer("destination-pin");
      }
      if (layers.contains("endpoint_logo")) {
        await mapController!.removeLayer("endpoint_logo");
      }
    } catch (e) {
      debugPrint("Error removing destination layers: $e");
    }

    // remove source
    try {
      final sources = await mapController!.getSourceIds();
      if (sources.contains("destination-source")) {
        await mapController!.removeSource("destination-source");
      }
    } catch (e) {
      debugPrint("Error removing destination source: $e");
    }

    // add a GeoJSON source for the single point
    await mapController?.addSource("destination-source", GeojsonSourceProperties(
        data: {
          "type": "FeatureCollection",
          "features": [{
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [location.longitude, location.latitude]
            }
          }]
        }
    ));

    // add a Circle Layer (guaranteed to render)
    await mapController?.addCircleLayer(
      "destination-source",
      "destination-pin",
      const CircleLayerProperties(
        circleColor: "#FF0000",      // ESU Red
        circleRadius: 12,            // Large enough to see
        circleStrokeWidth: 3,        // White border
        circleStrokeColor: "#FFFFFF",
        circleOpacity: 1.0,
      ),
    );
    await mapController?.addSymbolLayer(
      "destination-source",
      "endpoint_logo",
      SymbolLayerProperties(
        iconImage: "warrior_logo", // matches the name you gave in Step 4
        iconSize: 0.35,       // Adjust based on how big your PNG is
        iconAnchor: "bottom", // puts the tip of the pin on the spot
        iconAllowOverlap: true,
      ),
    );
  }

  void _handleLocationSelection(String destination) {

    final ll2.LatLng? endpoint = buildingData[destination]?.location;

    if (endpoint == null) {
      debugPrint('No coordinates found for $destination');
      return;
    }

    setState(() {
      _selectedDestinationName = destination;
      _endPoint = endpoint;
      _isRouting = false; // Reset to false when a new place is picked
      _routePolyline = []; // Clear the old route data
    });
    _stopRerouteTimer();

    // Clear old route lines from the map visually
    if (mapController != null) {
      mapController!.clearLines();
    }

    // Add the marker to the new destination
    _addDestinationMarker(_endPoint!);

    // Pan the camera to look at the destination (but don't tilt/route yet)
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_endPoint!.latitude, _endPoint!.longitude),
        17.5,
      ),
    );

    // If the sheet was shrunk from a previous route, pop it back up to 30%
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _addImageFromAsset(String name, String assetName) async {
    final ByteData bytes = await rootBundle.load(assetName);
    final Uint8List list = bytes.buffer.asUint8List();
    return mapController?.addImage(name, list);
  }

  void _onStyleLoaded() async {
    //debugPrint("Debug: making layers and buildings, onstyleloaded called");

    //debugging to see why grass layers are not loading
    final layers = await mapController!.getLayerIds();
    debugPrint("All map layers: $layers");

    await _addImageFromAsset("warrior_logo", "assets/images/esu_warrior_logo.png");
    await _addImageFromAsset("info_icon", "assets/images/info_icon.png");

    //add all layers concurrently instead of sequentially
    /*try {
      await Future.wait([
        //adding grass layer
        _addGrassLayer(),
        //adding tree layer
        _addTreeLayer(),
        //add 3D buildings
        _add3DBuildingsLayer(),
        //add clickable fill layer of building polygons
        _addBuildingTapLayer(),
        //place labels above 3d buildings
        _addLabelsLayer(),
      ]);
    }catch (e){
      debugPrint("Error during layer initialization: $e");
    }*/
    //add layers one-by-one to control the Z-Index (Bottom to Top)
    try {
       await _addGrassLayer();
       await _addTreeLayer();
       await _add3DBuildingsLayer();
       await _addLabelsLayer();
    } catch (e) {
      debugPrint("Error during layer initialization: $e");
    }
    // 4. Enable the blue dot now that the style is ready. Check permission one last time before telling the map to show the dot
    PermissionStatus permissionStatus = await _location.hasPermission();

    if (permissionStatus == PermissionStatus.granted && mounted) {
      // Only set this to true once we are certain we have permission
      await mapController?.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
      debugPrint("Blue dot engine started.");
      setState(() {
        _showBlueDot = true;
      });
      // We give the engine a small delay to process the state change
      //Future.delayed(const Duration(milliseconds: 500), () async {
        if (mapController != null) {
          // This 'kickstarts' the native location renderer
          await mapController!.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
          //debugPrint("Blue dot engine successfully kickstarted.");
        }
      //});
    } else {
      debugPrint("Location permission not granted yet - blue dot suppressed");
    }
    /*Future.delayed(const Duration(milliseconds: 200), () {
      if (mapController != null) {
        // This forces the "Blue Dot" engine to start
        mapController!.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
      }
    });*/

    /*building info debug check ups
    // Iterate over all buildings (e.g. to place map markers)
    buildingData.forEach((name, info) {
      debugPrint('${info.name} is at ${info.location}');
    });

    // Check how many buildings you have
    debugPrint('$buildingData.length');
     */
  }

  Widget _buildAboutSection() {
    if (_selectedDestinationName == null) return const SizedBox.shrink();

    //get the info on current chosen location
    final BuildingInfo? info = buildingData[_selectedDestinationName];
    if (info == null) return const Text("ℹ️ No details available for this location yet.");

    //build section based on its data
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //_buildImageGallery(info.imagePaths),
        Text(info.description, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        const Text("Hours:", style: TextStyle(fontWeight: FontWeight.bold)),
        ...info.formattedHours.map((line) => Text(line)),
      ],
    );
  }

  Widget _buildImageGallery(List<String> imagePaths) {
    // If no images yet, show nothing (handles buildings with empty imagePaths)
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200, //height of widget
          child: ListView.separated(
            scrollDirection: Axis.horizontal,   // horizontal scroll
            itemCount: imagePaths.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return SizedBox( //used to adjust individual image width
                width: 340,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    imagePaths[index],
                    fit: BoxFit.cover,  // width/height params no longer needed here
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using a Stack to put the Dropdown over the Map
      body: Stack(
        children: [
          // 1. The Map (Bottom Layer)
          Listener(
            onPointerDown: (PointerDownEvent event) {
              // Record where the finger first touched the screen
              _pointerDownPosition = event.localPosition;
              _pointerDownTime = DateTime.now();
            },
            onPointerUp: (PointerUpEvent event) async {
              if (_pointerDownPosition == null || mapController == null) return;

              // Check if the user tapped or dragged (panned the map).
              // If they moved their finger more than 10 pixels, it's a map pan, so ignore it.
              final distance = (event.localPosition - _pointerDownPosition!).distance;
              final elapsed = DateTime.now().difference(_pointerDownTime!);
              if (elapsed.inMilliseconds > 300 || distance > 10.0) return;

              debugPrint("flutter tap at ${event.localPosition}");

              // Convert Flutter Offset to MapLibre Point
              final dpr = MediaQuery.of(context).devicePixelRatio; //device pixel ratio, using to beat offset issues
              final screenPoint = Point<double>(
                  event.localPosition.dx * dpr,
                  event.localPosition.dy * dpr);

              final LatLng mapPoint = await mapController!.toLatLng(screenPoint);
              debugPrint("flutter tap map point: $mapPoint");

              // Run your existing ray-cast hit test
              final convertedPoint = ll2.LatLng(mapPoint.latitude, mapPoint.longitude);
              final tappedBuilding = _findTappedBuilding(convertedPoint);

              if (tappedBuilding != null) {
                debugPrint("Hit building: $tappedBuilding");
                _handleLocationSelection(tappedBuilding);
              } else {
                debugPrint("No building at tap location");
              }
              /*try {
                // Force MapLibre to tell us what is at this exact pixel coordinate,
                // looking ONLY for your red 3D tap layer.
                final features = await mapController!.queryRenderedFeatures(
                  screenPoint,
                  ['building-tap-layer'],
                  null,
                );

                if (features.isNotEmpty) {
                  final tappedBuilding = features.first['properties']?['name'];
                  debugPrint("🎯 SUCCESS Hit: $tappedBuilding");

                  if (tappedBuilding != null) {
                    _handleLocationSelection(tappedBuilding);
                  }
                } else {
                  debugPrint("Missed the red box.");
                }
              } catch (e) {
                debugPrint("Query error: $e");
              }*/
            },
            child: MapLibreMap(
              //enable the geolocation feature
              cameraTargetBounds: CameraTargetBounds(LatLngBounds(
                southwest: const LatLng(40.99203,-75.17833),
                northeast: const LatLng(40.9997558, -75.1597061),
              )),
              minMaxZoomPreference: const MinMaxZoomPreference(14.0, 21.0),
              myLocationEnabled: _showBlueDot,
              myLocationRenderMode: MyLocationRenderMode.normal, // Makes it follow you
              // Set tracking to None initially so it doesn't 'search' for GPS
              // before the native code is ready
              myLocationTrackingMode: MyLocationTrackingMode.none,

              styleString: "https://tiles.openfreemap.org/styles/bright",

              initialCameraPosition: const CameraPosition(
                target: LatLng(40.9959155, -75.173446),
                zoom: 17.0,
                tilt: 60,
              ),

              onMapCreated: (controller) => mapController = controller,
              onStyleLoadedCallback: _onStyleLoaded,
              //onMapClick: (point, latlng) => _handleMapTap(latlng),
              //onMapClick: (point, latlng) => _handleMapTap(point, latlng),
              /*onMapClick: (Point<double> screenPoint, LatLng mapPoint) async {
                debugPrint("TAP FIRED at screen=$screenPoint map=$mapPoint");
                if (mapController == null) return;

                try {
                  // 1. Query the exact Point, not a Rect.
                  // This avoids Flutter Device Pixel Ratio offset bugs.
                  final features = await mapController!.queryRenderedFeatures(
                    screenPoint,            // Pass the point directly
                    ['building-tap-layer'], // Only look for your red hitboxes
                    null,
                  );

                  if (features.isNotEmpty) {
                    final String? tappedBuilding = features.first['properties']?['name'];

                    if (tappedBuilding != null) {
                      debugPrint("SUCCESS! Hit building: $tappedBuilding");
                      _handleLocationSelection(tappedBuilding);
                      return;
                    }
                  }

                  debugPrint("Missed the Red Box. Map Point: ${mapPoint.latitude}, ${mapPoint.longitude}");
                  debugPrint("features size: ${features.length}");
                } catch (e) {
                  debugPrint("Query error: $e");
                }
              },*/
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
          ),
          // 2. The Dropdown (Top Layer)
          // positioning of search bar
          Positioned(
            top: 30,
            left: 10,
            right: 10,
            child: CampusSearchBar(

                onSelected: (selectedLocation) {
                  _handleLocationSelection(selectedLocation);
                },
              ),
          ),
          if (_showBlueDot) // Only show if location permissions/engine are active
            Positioned(
              bottom: 100, // Above your main FloatingActionButton
              right: 16,
              child: FloatingActionButton(
                heroTag: "gps_toggle_fab",
                mini: true,
                // Blue when following, grey when "free look"
                backgroundColor: _autoCenter ? Colors.blue : Colors.white,
                onPressed: () {
                  if(mounted) {
                    setState(() {
                      _autoCenter = !_autoCenter; // Toggle the boolean
                    });
                  }

                  // If turning ON, snap immediately to the user
                  if (_autoCenter && _currentUserLocation != null) {
                    mapController?.animateCamera(
                      CameraUpdate.newLatLng(
                        LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude),
                      ),
                    );
                  }
                },
                child: Icon(
                  _autoCenter ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: _autoCenter ? Colors.white : Colors.blue,
                ),
              ),
            ),
          if (_selectedDestinationName != null)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.3, // Starts at 30% of screen
              minChildSize: 0.1,     // Can shrink down to 10%
              maxChildSize: 0.9,     // Can pull up to 90%
              builder: (BuildContext context, ScrollController scrollController) {
                //the white box that is the menu background
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController, // Links scrolling to dragging
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The little grey handle at the top
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),

                          // Destination Name
                          Text(
                            _selectedDestinationName!,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          if (buildingData[_selectedDestinationName] != null)
                            Text(
                              buildingData[_selectedDestinationName]!.openStatus.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: buildingData[_selectedDestinationName]!.openStatus.color,
                              ),
                            ),
                          const SizedBox(height: 15),
                          _buildImageGallery(buildingData[_selectedDestinationName]!.imagePaths),
                          // The Route Button (Hides when routing starts)
                          //adding walking time estimate
                          if (!_isRouting && _walkingTimeEstimate.isNotEmpty)
                            Row(
                              children:[
                                const Icon(Icons.directions_walk, size: 18, color: Colors.blue),
                                const SizedBox(width:6),
                                Text(
                                _walkingTimeEstimate,
                                style: const TextStyle(
                                fontSize: 15,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                          else if(!_isRouting)
                            Row(
                              children: [
                                Icon(Icons.directions_walk, size: 18, color: Colors.grey [400]),
                                const SizedBox(width: 6),
                                Text(
                                  "Tap \"Start Route\" to see walk time",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[400],
                                    fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                          const SizedBox(height: 15),
                          //route button (hides when routing starts)
                          if(!_isRouting)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _startRouting,
                                icon: const Icon(Icons.directions_walk),
                                label: const Text("Start Route", style: TextStyle(fontSize: 18)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Navigating...",
                                  style: TextStyle(
                                    color:Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),

                          // Future Live Events Section Placeholder
                          const SizedBox(height: 30),
                          const Text("About This Building", style:TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            shadows: [
                              Shadow(
                                color: Colors.black,    // shadow color
                                offset: Offset(0, 0),   // (horizontal, vertical) shift
                                blurRadius: 4,          // how blurry/spread out it is
                              ),
                            ],
                          )
                          ),
                          // Info of all buildings outputted to user
                          const Divider(),
                          _buildAboutSection(), //builds about dynamically to fit chosen building
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
import 'package:latlong2/latlong.dart' as ll2;
import 'campus_dropdown.dart'; // calling dropdown class
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:flutter/services.dart' show rootBundle; // Required to load the file
import 'routing_service.dart'; // Ensure this file exists in your lib folder
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:async';
import 'dart:typed_data'; // Required for Uint8List
import 'package:flutter/foundation.dart'; // for compute()

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  // 1. Create the instance
  final RoutingService _routingService = RoutingService();

  //hosts the map platform and the layers within it
  MapLibreMapController? mapController;

  //Creating translation of string location to latlang coordinates
  static Map<String,ll2.LatLng> allLocations={
    //entrance of building
    'Laurel Residence Hall':ll2.LatLng(40.99605,-75.17303),
    //entrance of building
    'Shawnee Residence Hall': ll2.LatLng(40.99598,-75.17213),
    //entrance of building
    'Minsi Residence Hall': ll2.LatLng(40.99547,-75.17210),
    //entrance of building
    'Linden Residence Hall': ll2.LatLng(40.99605, -75.17105),
    //entrance of building
    'Hemlock Suites': ll2.LatLng(40.99799,-75.17100),
    //entrance of building
    'Lenape Residence Hall': ll2.LatLng(40.99866,-75.17193),
    //entrance of building
    'Hawthorn Suites' : ll2.LatLng(40.99908,-75.17233),
    //entrance of building
    'Sycamore Suites' : ll2.LatLng(40.99721,-75.17246),
    //entrance of building
    'Dansbury Commons' : ll2.LatLng(40.99671,-75.17351),
    //entrance of building
    'Monroe Hall' : ll2.LatLng(40.99525,-75.17283),
    //entrance of building
    'Koehler Fieldhouse and Natatorium' : ll2.LatLng(40.99710,-75.16993),
    //entrance of building
    'Kemp Library' : ll2.LatLng(40.99830,-75.17031),
    //entrance of building
    'Warren E. & Sandra Hoeffner Science and Technology Center' : ll2.LatLng(40.996636,-75.17557),
    //entrance of building
    'Moore Biology Hall' : ll2.LatLng(40.99631,-75.17498),
    //entrance of building
    'Gessner Science Hall' : ll2.LatLng(40.9959637,-75.1748588),
    //entrance of building
    'Stroud Hall' : ll2.LatLng(40.99530,-75.17441),
    //entrance of building
    'DeNike Center for Human Services' : ll2.LatLng(40.99413,-75.17611),
    //entrance of building
    'Fine and Performing Arts Center' : ll2.LatLng(40.99855,-75.16642),
    //entrance of building
    'Zimbar-Liljenstein Hall' : ll2.LatLng(40.99413,-75.17380),
    //entrance of field (change this one?)
    'Eiler-Martin Stadium' : ll2.LatLng(40.9940069,-75.1728448),
    //this one seems fine
    'Dave Carllyon Pavilion' : ll2.LatLng(40.9985246,-75.1728687),
    //entrance of building
    'Mattioli Recreation Center' : ll2.LatLng(40.99546,-75.17034),
    //unchanged
    'Joseph H. & Mildred E. Beers Lecture Hall' : ll2.LatLng(40.9954604,-75.1750394),
    //entrance of builing
    'Reibman Administration Building' : ll2.LatLng(40.99564,-75.17683),
    //entrance of building
    'Conference Services & Multicultural House' : ll2.LatLng(40.99587,-75.17637),
    //entrance of building
    'Abeloff Center for the Performing Arts' : ll2.LatLng(40.99453,-75.17533),
    //entrance of building
    'Rosenkrans Hall' : ll2.LatLng(40.99494,-75.17467),
    //iffy on where to add entrance
    'University Center' : ll2.LatLng(40.99604,-75.17384),
    //unchanged
    'Henry A. Ahnert Jr. Alumni Center' :  ll2.LatLng(40.9996531,-75.1713405),
  };

  // State variables to track navigation
  ll2.LatLng? _startPoint;
  ll2.LatLng? _endPoint;
  List<ll2.LatLng> _routePolyline = [];
  bool _isGraphLoaded = false;

  //state variable for time of distance
  String _walkingTimeEstimate = "";

  bool _showBlueDot = false;
  bool _useCurrentLocation = false;
  bool _autoCenter = true;
  ll2.LatLng? _currentUserLocation;

  String? _selectedDestinationName;
  bool _isRouting = false;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  //location package
  final Location _location = Location();

  //Debounce timers to prevent excessive setState calls
  Timer? _locationUpdateTimer;
  Timer? _routeUpdateTimer;
  StreamSubscription<LocationData>? _locationSubscription;


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
    super.dispose();
  }

  //async method
  Future<void> _initializeAsync() async {
    //starting both operations concurrently instead of sequentially
    await Future.wait([
      _initializeRouting(),
      _requestLocationPermissionAndCenter(),
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

      bool needsUpdate = false;

      if(_useCurrentLocation){
        _startPoint = _currentUserLocation;
        needsUpdate = true;

        //debounce route recalculation
        if(_endPoint != null){
          _scheduleRouteUpdate();
        }
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
    _routeUpdateTimer = Timer(const Duration(milliseconds: 1000), (){
      if(_startPoint != null && _endPoint != null && mounted){
        final newRoute = _routingService.getRoute(_startPoint!, _endPoint!);
        if(mounted){
          setState(() {
            _routePolyline = newRoute;
          });
          addRouteLayer(_routePolyline);
        }
      }
    });
  }

    //location updates and recenter if needed
   /* _location.onLocationChanged.listen((LocationData newLoc){
      if(newLoc.latitude != null && newLoc.longitude != null){
        _currentUserLocation = ll2.LatLng(newLoc.latitude!, newLoc.longitude!);
        if(_useCurrentLocation){
          setState(() {
            _startPoint = _currentUserLocation;
            // If they already picked a destination, update the route live as they walk
            if (_endPoint != null) {
              _routePolyline = _routingService.getRoute(_startPoint!, _endPoint!);
            }
          });
        }
        if(_autoCenter){//only continue to recenter if the user wants it
          mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(newLoc.latitude!, newLoc.longitude!),
              mapController?.cameraPosition?.zoom ?? 17.0,
            ),
          );
        }
      }
    });*/
  //

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

  //Handle the Tap Logic
  Future<void> _onMapTap(ll2.LatLng point) async {
    if (!_isGraphLoaded) return; // Don't allow taps until data is ready
    //debugPrint("Debug: _onMapTap: entered");
    if (_useCurrentLocation && _currentUserLocation == null) {
      final LocationData forcedLoc = await _location.getLocation();
      if (forcedLoc.latitude != null && mounted) {
        setState(() {
          _currentUserLocation = ll2.LatLng(forcedLoc.latitude!, forcedLoc.longitude!);
        });
      }
    }

    //Calculate route outside setState, then update once
    ll2.LatLng? newStart;
    ll2.LatLng? newEnd;


    //setState(() {
      //gps is start, tap is always the destination
      if(_useCurrentLocation){
        if(_currentUserLocation == null) {
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Debug: _onMapTap: GPS location not found")),
            );
          }
          return;
        }
        //set destination to tap point
        debugPrint("Debug: _onMapTap: GPS mode on -> location found");
        newStart = _currentUserLocation;
        newEnd = point;
      }else{
        //manual start and end select mode
        //debugPrint("Debug: _onMapTap: Manual mode on");
        if (_startPoint == null || (_startPoint != null && _endPoint != null)) {
          // Start fresh: set Point A and clear old route
          newStart = point;
          newEnd = null;
          //_routePolyline = [];
        }else{
          // Set Point B and calculate the path
          newStart = _startPoint;
          newEnd = point;
        }
      }
      if(mounted){
        setState(() {
          _startPoint = newStart;
          _endPoint = newEnd;
        });
      }
    //_drawMarkers(); // Updates the green/red dots
    if (_startPoint != null && _endPoint != null) {
      debugPrint("Debug: _onMapTap: drawing path from $_startPoint to $_endPoint");
      _makePath(_startPoint!, _endPoint!); // Updates the route line
    }
  }

  // This handles the click from MapLibre and converts it for your RoutingService
  void _handleMapTap(LatLng mapLibrePoint) {
    // Convert MapLibre LatLng to your existing ll2.LatLng format
    final convertedPoint = ll2.LatLng(
        mapLibrePoint.latitude,
        mapLibrePoint.longitude
    );
    debugPrint("Debug: _handleMapTap: user tapped point: $convertedPoint");

    // Now call your existing logic that handles routing and markers
    _onMapTap(convertedPoint);
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

  //puts 3d buildings on map
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
          fillExtrusionColor: '#808080',
          // 'render_height' is the property in OSM data that tells us how tall it is
          fillExtrusionHeight: ["*", ["get", "render_height"], 1.5],
          fillExtrusionBase: ["get", "render_min_height"],
          fillExtrusionOpacity: 0.9,
          //add vertical shading to buildings
          fillExtrusionVerticalGradient: true,
        ),
        //belowLayerId: firstSymbolId,
        sourceLayer: "building",
      );
      debugPrint("3D buildings layer added successfully");
    }catch (e){
      debugPrint("Error adding 3D buildings layer: $e");
    }
  }

  //puts directional labels over designated buildings
  static const Map<String,dynamic> _buildingLabelsData = {
    //if (mapController == null) return;

   // try {
      // 1. Add Source
      //await mapController!.addSource("building-labels-source", GeojsonSourceProperties(
          //data: {
            "type": "FeatureCollection",
            "features": [
              { "type": "Feature", "properties": { "name": "Eiler-Martin Stadium" }, "geometry": { "type": "Point", "coordinates": [-75.1727, 40.9936] } },
              { "type": "Feature", "properties": { "name": "Dansbury Commons" }, "geometry": { "type": "Point", "coordinates": [-75.1736, 40.9970] } },
              { "type": "Feature", "properties": { "name": "Flagler-Metzgar Center" }, "geometry": { "type": "Point", "coordinates": [-75.1729, 40.9970] } },
              { "type": "Feature", "properties": { "name": "Monroe Hall" }, "geometry": { "type": "Point", "coordinates": [-75.1727, 40.9951] } },
              { "type": "Feature", "properties": { "name": "Koehler Fieldhouse and Natatorium" }, "geometry": { "type": "Point", "coordinates": [-75.1703, 40.9968] } },
              { "type": "Feature", "properties": { "name": "Kemp Library" }, "geometry": { "type": "Point", "coordinates": [-75.1701, 40.9984] } },
              { "type": "Feature", "properties": { "name": "Mattioli Recreation Center" }, "geometry": { "type": "Point", "coordinates": [-75.1701, 40.9953] } },
              { "type": "Feature", "properties": { "name": "Computing Center" }, "geometry": { "type": "Point", "coordinates": [-75.1745, 40.9959] } },
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
      //));
      //debugPrint("Source added.");
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
      //debugPrint("Label layer command sent.");

      /* 3. confirming layer existence
      final finalLayers = await mapController!.getLayerIds();
      if (finalLayers.contains("building-labels-display-layer")) {
        debugPrint("SUCCESS: 'building-labels-display-layer' is now in the map tree!");
      } else {
        debugPrint("FAILURE: Layer still not in map tree. Check native logs (Logcat/Xcode).");
      }*/

   // } catch (e) {
     // debugPrint("CRASH in _setupMapLayers: $e");
   // }

  //}

  //allows routing to work properly by adding the data of the walkways to the mapcontroller as a layer
  //routing basically reveals parts of this layer necessary to make the path
  Future<void> _addRouteSource() async {
    debugPrint("Debug: setupMapLayers entered");
    if (mapController == null) return;

    // 1. Setup Route Layer (Bottom)
    // We initialize it with an empty FeatureCollection so it doesn't show yet
    await mapController!.addSource("route-source", const GeojsonSourceProperties(
        data: {"type": "FeatureCollection", "features": []}
    ));
    await mapController!.addLineLayer(
      "route-source",
      "route-layer",
      const LineLayerProperties(
        lineColor: '#2196F3', // Red
        lineWidth: 6.0,
        lineJoin: "round",
        lineCap: "round",
      ),
    );
  }
  // This actually talks to the MapLibre engine to visualize the path from _makePath
  Future<void> addRouteLayer(List<ll2.LatLng> points) async {
    if (mapController == null || points.isEmpty) return;

    //convert points to maplibre verison of LatLng
    final List<LatLng> convertedPoints = points.map((point) => LatLng(point.latitude, point.longitude)).toList();

    try {
      // 1. Clear previous attempt to avoid Duplicate ID crash
      await mapController!.clearLines();

      // 2. Add the new line
      await mapController!.addLine(
        LineOptions(
          geometry: convertedPoints,
          lineColor: "#FF0000",
          lineWidth: 4.0,
        ),
      );
    } catch (e) {
      debugPrint("Caught map error: $e");
    }
  }


  Future<void> _addDestinationMarker(ll2.LatLng location) async {
    if (mapController == null) return;

    // Remove layer FIRST (must happen before removing source)
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

    // THEN remove source
    try {
      final sources = await mapController!.getSourceIds();
      if (sources.contains("destination-source")) {
        await mapController!.removeSource("destination-source");
      }
    } catch (e) {
      debugPrint("Error removing destination source: $e");
    }

    // Now safely add fresh source and layers
    // OLD 1. Remove old marker layer if it exists
    //try { await mapController?.removeLayer("destination-pin"); } catch (e) {}
    //try { await mapController?.removeSource("destination-source"); } catch (e) {}

    // 2. Add a GeoJSON source for the single point
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

    // 3. Add a Circle Layer (guaranteed to render)
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
        iconAnchor: "bottom", // IMPORTANT: puts the tip of the pin on the spot
        iconAllowOverlap: true,
      ),
    );
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

    //print all point in the path
    /*print("Path points: ");
    for(int i = 0; i < path.length; i++){
      print(path[i]);
    }*/
    addRouteLayer(_routePolyline);//new way to draw 3D maplibre path
  }

  // simple method to handle the users start point and route to users end point from selected option from dropdown menu
  /*void _handleLocationSelection(String destination){
    // creating variable endpoint from list of dorm building names
    final ll2.LatLng? endpoint = allLocations[destination];
    _startPoint = _currentUserLocation; // re initializing _startpoint to be current user location

    if(endpoint == null){
      debugPrint('No coordinates found for $destination');
      return;
    }

    //set start to user if allowed to prevent a crash
    if(_useCurrentLocation){
      if (_currentUserLocation != null) {
        _startPoint = _currentUserLocation;
      } else {
        // GPS is on but we don't have a fix yet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Waiting for GPS location...")),
        );
        return; // Stop here to prevent crash
      }
    }
    //otherwise tell them to make a start point
    if(_startPoint==null){
      debugPrint('Start point not set yet.');
      if(mounted) {
        //send snackbar message to show user issue
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Start point not set yet")),
        );
      }
      return;
    }
    if(mounted) {
      setState(() {
        _endPoint =
            endpoint; // setting the _endpoint to be the value from dormLocations list
        //_routePolyline = _routingService.getRoute(_startPoint!, _endPoint!); // restating polyline
      });
    }
    // Add the marker to the map
    _addDestinationMarker(_endPoint!);
    _makePath(_startPoint!, _endPoint!);//draw path to selection
    _tiltAndRotateCamera(_startPoint!, _endPoint!);
  }*/
  void _handleLocationSelection(String destination) {
    final ll2.LatLng? endpoint = allLocations[destination];

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

  void _startRouting() {
    // 1. Ensure we have a start point
    _startPoint = _useCurrentLocation ? _currentUserLocation : _startPoint;

    if (_startPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Start point not set yet. Waiting for GPS or manual tap.")),
      );
      return;
    }

    // 2. Update state to show we are navigating
    setState(() {
      _isRouting = true;
    });

    // 3. Draw the path and move the camera
    _makePath(_startPoint!, _endPoint!);
    _tiltAndRotateCamera(_startPoint!, _endPoint!);

    // 4. Shrink the pull-up menu down to 15% of the screen
    _sheetController.animateTo(
      0.15,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onStyleLoaded() async {
    //debugPrint("Debug: making layers and buildings, onstyleloaded called");

    await _addImageFromAsset("warrior_logo", "assets/images/esu_warrior_logo.png");
    await _addImageFromAsset("info_icon", "assets/images/info_icon.png");

    //add all layers concurrently instead of sequentially
    try {
      await Future.wait([
        // 1. Add 3D buildings
      _add3DBuildingsLayer(),
      // 2. create layers for the user, route, and blue dot
       _addLabelsLayer(),
      // 3. add the source data for routing
       _addRouteSource(),
      ]);
    }catch (e){
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
    // 4. Enable the blue dot now that the style is ready
    /*Future.delayed(const Duration(milliseconds: 200), () {
      if (mapController != null) {
        // This forces the "Blue Dot" engine to start
        mapController!.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
      }
    });*/
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // GPS Toggle Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!_useCurrentLocation) {
            bool hasPermission = await _handleLocationPermission();
            if (!hasPermission) return;
          }
          if(mounted) {
            setState(() {
              _useCurrentLocation = !_useCurrentLocation;
              if (_useCurrentLocation && _currentUserLocation != null) {
                _startPoint = _currentUserLocation;
                // Update route if destination exists
                if (_endPoint != null) {
                  _makePath(_startPoint!, _endPoint!);
                }
              }
            });
          }
        },
        label: Text(_useCurrentLocation ? "GPS Start" : "Manual Start"),
        icon: Icon(_useCurrentLocation ? Icons.my_location : Icons.edit_location),
        backgroundColor: _useCurrentLocation ? Colors.blue : Colors.grey,
      ),

      // KEY CHANGE: Use a Stack to put the Dropdown ON TOP of the Map
      body: Stack(
        children: [
          // 1. The Map (Bottom Layer)
          MapLibreMap(
            //enable the geolocation feature
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
            onMapClick: (point, latlng) => _handleMapTap(latlng),
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
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
                          const SizedBox(height: 15),

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
                          const Text("Events Today", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          // Your StreamBuilder will go here later
                          const Text("No events scheduled for this location today."),
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
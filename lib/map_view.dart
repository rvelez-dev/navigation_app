import 'package:latlong2/latlong.dart' as ll2;
import 'campus_dropdown.dart'; // calling dropdown class
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:flutter/services.dart' show rootBundle; // Required to load the file
import 'routing_service.dart'; // Ensure this file exists in your lib folder
import 'package:maplibre_gl/maplibre_gl.dart';

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
  final Map<String,ll2.LatLng> allLocations={
    'Laurel Residence Hall':ll2.LatLng(40.9959155,-75.173446),
    'Shawnee Residence Hall': ll2.LatLng(40.9963692,-75.1718578),
    'Minsi Residence Hall': ll2.LatLng(40.9955957,-75.1712977),
    'Linden Residence Hall': ll2.LatLng(40.9965415, -75.171232),
    'Hemlock Suites': ll2.LatLng(40.9982059,-75.1716599),
    'Lenape Residence Hall': ll2.LatLng(40.9984213,-75.1723409),
    'Hawthorn Suites' : ll2.LatLng(40.9994416,-75.1733226),
    'Sycamore Suites' : ll2.LatLng(40.9971008,-75.1717411),
    'Dansbury Commons' : ll2.LatLng(40.9970549,-75.174138),
    'Monroe Hall' : ll2.LatLng(40.9950679,-75.1731268),
    'Koehler Fieldhouse and Natatorium' : ll2.LatLng(40.9970549,-75.1711553),
    'Kemp Library' : ll2.LatLng(40.998535,-75.1705461),
    'Warren E. & Sandra Hoeffner Science and Technology Center' : ll2.LatLng(40.9965026,-75.1761235),
    'Moore Biology Hall' : ll2.LatLng(40.9963108,-75.1750235),
    'Gessner Science Hall' : ll2.LatLng(40.9959637,-75.1748588),
    'Stroud Hall' : ll2.LatLng(40.9957886,-75.1746249),
    'DeNike Center for Human Services' : ll2.LatLng(40.9936593,-75.1764988),
    'Fine and Performing Arts Center' : ll2.LatLng(40.9987711,-75.1665964),
    'Zimbar-Liljenstein Hall' : ll2.LatLng(40.9938668,-75.1739783),
    'Eiler-Martin Stadium' : ll2.LatLng(40.9940069,-75.1728448),
    'Dave Carllyon Pavilion' : ll2.LatLng(40.9985246,-75.1728687),
    'Mattioli Recreation Center' : ll2.LatLng(40.995681,-75.1699969),
    'Joseph H. & Mildred E. Beers Lecture Hall' : ll2.LatLng(40.9954604,-75.1750394),
    'Reibman Administration Building' : ll2.LatLng(40.9958995,-75.1770572),
    'Conference Services & Multicultural House' : ll2.LatLng(40.9957553,-75.1764082),
    'Abeloff Center for the Performing Arts' : ll2.LatLng(40.9944137,-75.1753685),
    'Rosenkrans Hall' : ll2.LatLng(40.9948232,-75.1749201),
    'University Center' : ll2.LatLng(40.9956658,-75.1739196),
    'Henry A. Ahnert Jr. Alumni Center' :  ll2.LatLng(40.9996531,-75.1713405),
  };

  // State variables to track navigation
  ll2.LatLng? _startPoint;
  ll2.LatLng? _endPoint;
  List<ll2.LatLng> _routePolyline = [];
  bool _isGraphLoaded = false;

  bool _showBlueDot = false;
  bool _useCurrentLocation = false;
  bool _autoCenter = true;
  ll2.LatLng? _currentUserLocation;

  //location package
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _initializeRouting();
    _requestLocationPermissionAndCenter();
  }

  // 2. Load the GeoJSON file into the service
  Future<void> _initializeRouting() async {
    try {
      final String geoJsonData = await rootBundle.loadString(
          'assets/esu_jsons/walkways.geojson');
      _routingService.loadGeoJson(geoJsonData);
      setState(() {
        _isGraphLoaded = true;
      });
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
      interval: 1500, // Update every 1.5 seconds
      distanceFilter: 0, // Even if the user hasn't moved
    );

    //Getting current location and move map accordingly
    final LocationData userLocation = await _location.getLocation();
    if(userLocation.latitude !=null && userLocation.longitude != null){
      setState(() {
        // SAVE the location to your variable here!
        _currentUserLocation = ll2.LatLng(userLocation.latitude!, userLocation.longitude!);
      });

      //initial lock on to user location
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(userLocation.latitude!, userLocation.longitude!),
            mapController?.cameraPosition?.zoom ?? 17.0,
        ),
      );
      setState(() {}); // refreshes map to show currentLocationLayer
    }

    //location updates and recenter if needed
    _location.onLocationChanged.listen((LocationData newLoc){
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
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission is permanently denied. Please enable it in settings.")),
      );
      return false;
    }

    return true;
  }

  //Handle the Tap Logic
  Future<void> _onMapTap(ll2.LatLng point) async {
    if (!_isGraphLoaded) return; // Don't allow taps until data is ready
    debugPrint("Debug: _onMapTap: entered");
    if (_useCurrentLocation && _currentUserLocation == null) {
      final LocationData forcedLoc = await _location.getLocation();
      if (forcedLoc.latitude != null) {
        setState(() {
          _currentUserLocation = ll2.LatLng(forcedLoc.latitude!, forcedLoc.longitude!);
        });
      }
    }

    setState(() {
      //gps is start, tap is always the destination
      if(_useCurrentLocation){
        if(_currentUserLocation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content:  Text("Debug: _onMapTap: GPS location not found")),
          );
          return;
        }
        //set destination to tap point
        debugPrint("Debug: _onMapTap: GPS mode on -> location found");
        _startPoint = _currentUserLocation;
        _endPoint = point;
      }else{
        //manual start and end select mode
        debugPrint("Debug: _onMapTap: Manual mode on");
        if (_startPoint == null || (_startPoint != null && _endPoint != null)) {
          // Start fresh: set Point A and clear old route
          _startPoint = point;
          _endPoint = null;
          //_routePolyline = [];
        }else{
          // Set Point B and calculate the path
          _endPoint = point;
        }
      }
    });
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

    //-addressing 3D being under map and labels layers-
    // 1. Get all layers from the style to find where to insert
    final layers = await mapController!.getLayerIds();

    // 2. Find the first layer that contains labels (symbols)
    // so buildings don't cover the street names
    String? firstSymbolId;
    for (var id in layers) {
      if (id.contains('label') || id.contains('place') || id.contains('poi')) {
        firstSymbolId = id;
        break;
      }
    }

    // This adds the 3D extrusion layer to the map style
    try {
      await mapController!.addLayer(
        "openmaptiles",
        // This is the standard source layer name in OpenFreeMap tiles
        "3d-buildings", // A unique ID we give to this new 3D layer
        const FillExtrusionLayerProperties(
          // Color of the buildings
          fillExtrusionColor: '#808080',
          // 'render_height' is the property in OSM data that tells us how tall it is
          fillExtrusionHeight: ["*", ["get", "render_height"], 1.5],
          fillExtrusionBase: ["get", "render_min_height"],
          fillExtrusionOpacity: 0.9,
          //add vertical shading to buildings
          fillExtrusionVerticalGradient: true,
        ),
        belowLayerId: firstSymbolId,
        sourceLayer: "building",
      );
      debugPrint("3D buildings layer added successfully");
    }catch (e){
      debugPrint("Error adding 3D buildings layer: $e");
    }
  }

  //puts directional labels over designated buildings
  Future<void> _addLabelsLayer() async {
    if (mapController == null) return;

    try {
      // 1. Add Source
      await mapController!.addSource("building-labels-source", GeojsonSourceProperties(
          data: {
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
          }
      ));
      //debugPrint("Source added.");

      // 2. Add Symbol Layer
      await mapController!.addSymbolLayer(
        "building-labels-source",
        "building-labels-display-layer",
        const SymbolLayerProperties(
          textField: ["get", "name"],
          textColor: "#333333",
          // "Open Sans Bold" is crisper than Regular.
          // If it fails to load, it will fall back to the map's default.
          textFont: ["Noto Sans Regular"],
          textTransform: "uppercase", // Makes it look like an official blueprint
          textLetterSpacing: 0.1,
          //textSize: 14,
          textSize: [
            "interpolate",
            ["linear"],
            ["zoom"],
            15, 10.0,
            18, 14.0
          ],
          // A white outline ensures text is readable on top of grey buildings
          textHaloColor: "#FFFFFF",
          textHaloWidth: 2.0,
          textHaloBlur: 0.5, // Softens the edge of the halo

          textAllowOverlap: true,

        ),
      );
      //debugPrint("Label layer command sent.");

      /* 3. confirming layer existence
      final finalLayers = await mapController!.getLayerIds();
      if (finalLayers.contains("building-labels-display-layer")) {
        debugPrint("SUCCESS: 'building-labels-display-layer' is now in the map tree!");
      } else {
        debugPrint("FAILURE: Layer still not in map tree. Check native logs (Logcat/Xcode).");
      }*/

    } catch (e) {
      debugPrint("CRASH in _setupMapLayers: $e");
    }

  }

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

  //Creates the route points argument for draw route using a given start and end, calls _addRouteLayer
  void _makePath(ll2.LatLng start, ll2.LatLng end){
    debugPrint("Debug: Calling routing service");
    final path = _routingService.getRoute(start, end);
    setState(() {
      _routePolyline = path;
    });
    //print all point in the path
    /*print("Path points: ");
    for(int i = 0; i < path.length; i++){
      print(path[i]);
    }*/
    addRouteLayer(_routePolyline);//new way to draw 3D maplibre path
  }

  // simple method to handle the users start point and route to users end point from selected option from dropdown menu
  void _handleLocationSelection(String destination){
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
      //send snackbar message to show user issue
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:  Text("Start point not set yet")),
      );
      return;
    }

    setState(() {
      _endPoint = endpoint; // setting the _endpoint to be the value from dormLocations list
      //_routePolyline = _routingService.getRoute(_startPoint!, _endPoint!); // restating polyline
    });
    _makePath(_startPoint!, _endPoint!);//draw path to selection
    _tiltAndRotateCamera(_startPoint!, _endPoint!);
  }


  void _onStyleLoaded() async {
    debugPrint("Debug: making layers and buildings, onstyleloaded called");

    // 1. Add 3D buildings
    await _add3DBuildingsLayer();
    // 2. create layers for the user, route, and blue dot
    await _addLabelsLayer();
    // 3. add the source data for routing
    await _addRouteSource();

    // 4. Enable the blue dot now that the style is ready. Check permission one last time before telling the map to show the dot
    PermissionStatus permissionStatus = await _location.hasPermission();

    if (permissionStatus == PermissionStatus.granted) {
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
          debugPrint("Blue dot engine successfully kickstarted.");
        }
      //});
    } else {
      debugPrint("Location permission not granted yet - blue dot suppressed");
    }
    // 4. Enable the blue dot now that the style is ready
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mapController != null) {
        // This forces the "Blue Dot" engine to start
        mapController!.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
      }
    });
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
                  setState(() {
                    _autoCenter = !_autoCenter; // Toggle the boolean
                  });

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
        ],
      ),
    );
  }
}
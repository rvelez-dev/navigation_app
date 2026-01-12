import 'package:latlong2/latlong.dart' as ll2;
import 'campus_dropdown.dart'; // calling dropdown class
import 'package:flutter/material.dart';
import 'package:location/location.dart';
//import 'package:geolocator/geolocator.dart';
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

  // marker of user
  //final MapController mapController = MapController();
  MapLibreMapController? mapController;

  //Creating translation of string location to latlang coordinates
  final Map<String,ll2.LatLng> dormLocations={
    'Laurel Residence Hall':ll2.LatLng(40.9959155,-75.173446),
    'Shawnee Residence Hall': ll2.LatLng(40.9963692,-75.1718578),
    'Minsi Residence Hall': ll2.LatLng(40.9955957,-75.1712977),
    'Linden Residence Hall': ll2.LatLng(40.9965415, -75.171232),
    'Hemlock Suites': ll2.LatLng(40.9982059,-75.1716599),
    'Lenape Residence Hall': ll2.LatLng(40.9984213,-75.1723409),
    'Hawthorn Suites' : ll2.LatLng(40.9994416,-75.1733226),
    'Sycamore Suites' : ll2.LatLng(40.9971008,-75.1717411)

};

  // State variables to track navigation
  ll2.LatLng? _startPoint;
  ll2.LatLng? _endPoint;
  List<ll2.LatLng> _routePolyline = [];
  bool _isGraphLoaded = false;

  bool _showBlueDot = false;
  bool _useCurrentLocation = false;
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
      /*mapController.move(
        ll2.LatLng(userLocation.latitude!, userLocation.longitude!),
        16.2, // zoom
      );*/
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
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(newLoc.latitude!, newLoc.longitude!),
            mapController?.cameraPosition?.zoom ?? 17.0,
          ),
        );
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

  //3. Setup Separate Layers
  void _setupMapLayers() async {
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
        lineColor: '#2196F3', // Blue
        lineWidth: 6.0,
        lineJoin: "round",
        lineCap: "round",
      ),
    );

    // 2. Setup Start Point Layer (Green Dot)
    await mapController!.addSource("start-source", const GeojsonSourceProperties(
        data: {"type": "FeatureCollection", "features": []}
    ));
    await mapController!.addCircleLayer(
      "start-source",
      "start-layer",
      const CircleLayerProperties(
        circleColor: '#4CAF50', // Green
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: '#FFFFFF',
      ),
    );

    // 3. Setup End Point Layer (Red Dot)
    await mapController!.addSource("end-source", const GeojsonSourceProperties(
        data: {"type": "FeatureCollection", "features": []}
    ));
    await mapController!.addCircleLayer(
      "end-source",
      "end-layer",
      const CircleLayerProperties(
        circleColor: '#F44336', // Red
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: '#FFFFFF',
      ),
    );

    // 4. Force "My Location" to be visible
    //await mapController!.setMyLocationEnabled(true);
  }

  //4. Handle the Tap Logic
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
      _makePath(_startPoint!, _endPoint!); // Updates the blue line
    }
  }
  //new wrapper function with maplibre
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


  //puts 3d buildings on map
  void _add3DBuildingsLayer() async {
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
          fillExtrusionColor: '#000000',
          // Color of the buildings
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
      print("3D buildings layer added successfully");
    }catch (e){
      print("Error adding 3D buildings layer: $e");
    }
  }

  void _drawMarkers() async {
    /*if (mapController == null) return;

    // Update Start Point Data
    if (_startPoint != null) {
      debugPrint("Debug: drawing start point");
      await mapController!.setGeoJsonSource("start-source", {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [_startPoint!.longitude, _startPoint!.latitude]
        },
        "properties": {} // Empty properties prevents some parser errors
      });
    } //else {
      // If null, hide it by sending empty data
      //await mapController!.setGeoJsonSource("start-source", {"type": "FeatureCollection", "features": []});
    //}

    // Update End Point Data
    if (_endPoint != null) {
      debugPrint("Debug: drawing end point");
      await mapController!.setGeoJsonSource("end-source", {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [_endPoint!.longitude, _endPoint!.latitude]
        },
        "properties": {}
      });
    } //else {
      //await mapController!.setGeoJsonSource("end-source", {"type": "FeatureCollection", "features": []});
    //}*/
    /*if (mapController == null) return;

    try {
      // 1. Handle Start Point Marker
      if (_startPoint != null) {
        debugPrint("Debug: Updating start-source with point");
        await mapController!.setGeoJsonSource("start-source", {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [_startPoint!.longitude, _startPoint!.latitude]
          },
          "properties": {}
        });
        await mapController!.setGeoJsonSource("start-source", jsonEncode(startGeoJson) );
      } else {
        // Explicitly clear if null, don't remove the source
        await mapController!.setGeoJsonSource("start-source", jsonEncode( {"type": "FeatureCollection", "features": []}) );
      }

      // 2. Handle End Point Marker
      if (_endPoint != null) {
        debugPrint("Debug: Updating end-source with point");
        await mapController!.setGeoJsonSource("end-source", {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [_endPoint!.longitude, _endPoint!.latitude]
          },
          "properties": {}
        });
        await mapController!.setGeoJsonSource("end-source", jsonEncode(endGeoJson));
      } else {
        await mapController!.setGeoJsonSource("end-source", jsonEncode({"type": "FeatureCollection", "features": []}));
      }
    } catch (e) {
      debugPrint("MapLibre Error in _drawMarkers: $e");
    }*/
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
      print("Caught map error: $e");
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
    print("Path points: ");
    for(int i = 0; i < path.length; i++){
      print(path[i]);
    }
    addRouteLayer(_routePolyline);//new way to draw 3D maplibre path
  }

  // simple method to handle the users start point and route to users end point from selected option from dropdown menu
  void _handleLocationSelection(String destination){
    // creating variable endpoint from list of dorm building names
    final ll2.LatLng? endpoint = dormLocations[destination];
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
    //_drawMarkers();
    _makePath(_startPoint!, _endPoint!);//draw path to selection

  }

  void _onStyleLoaded() async {
    debugPrint("Debug: making layers and buildings, onstyleloaded called");
    // 1. Add 3D buildings
    _add3DBuildingsLayer();
    // 2. create layers for the user, route, start, and end points
    _setupMapLayers();

    // 3. Check permission one last time before telling the map to show the dot
    PermissionStatus permissionStatus = await _location.hasPermission(); //

    if (permissionStatus == PermissionStatus.granted) {
      // Only set this to true AFTER we are certain we have permission
      await mapController?.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
      debugPrint("Blue dot engine started.");
      setState(() {
        _showBlueDot = true;
      });
      // We give the engine a small delay to process the state change
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mapController != null) {
          // This 'kickstarts' the native location renderer
          await mapController!.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
          debugPrint("Blue dot engine successfully kickstarted.");
        }
      });
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

  //@override
  /*Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar( //header where esu navigation is at
          foregroundColor: Colors.white,
          title: const Text('ESU Navigation'),
          backgroundColor: Colors.redAccent,
          actions: [
            if (_startPoint != null)
              IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () =>
                      setState(() {
                        _startPoint = null;
                        _endPoint = null;
                        _routePolyline = [];
                      })
              )
          ],
        ),

        // new toggle button for gps start
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            // If we are trying to turn GPS mode ON, check permissions first
            if (!_useCurrentLocation) {
              bool hasPermission = await _handleLocationPermission();
              if (!hasPermission) return; // Exit if they didn't allow it
            }
            setState(() {
              _useCurrentLocation = !_useCurrentLocation;

              if(_useCurrentLocation){//gps mode on
                if(_currentUserLocation != null){//if users location
                  _startPoint = _currentUserLocation;//move start marker to there

                  //if there is an existing destination change start point to user and redraw path
                  if(_endPoint != null) {
                    _routePolyline = _routingService.getRoute(_startPoint!, _endPoint!);
                  }
               }
              }
            });
          },
          label: Text(_useCurrentLocation ? "GPS Start" : "Manual Start"),
          icon: Icon(_useCurrentLocation ? Icons.my_location : Icons.edit_location),
          backgroundColor: _useCurrentLocation ? Colors.blue : Colors.grey,
        ),

        body : MapLibreMap(
          // Use OpenFreeMap - it's OSM based and free
          styleString: "https://tiles.openfreemap.org/styles/bright",

          initialCameraPosition: const CameraPosition(
            target: LatLng(40.9959155, -75.173446), // campus center
            zoom: 17.0,
            //ange camera 45 degrees along pitch
            tilt: 60,
          ),

          onMapCreated: (MapLibreMapController controller) {
            mapController = controller;
          },

          // This is where we will enable the 3D buildings
          /*onStyleLoadedCallback: () {
            _add3DBuildingsLayer();

            Future.delayed(const Duration(milliseconds: 500), () {
              mapController?.animateCamera(
                CameraUpdate.tiltTo(60.0),
              );
            });
          },*/
          onStyleLoadedCallback: _add3DBuildingsLayer,

          // This replaces the 'onTap' from FlutterMap
          onMapClick: (point, latlng) {
            _handleMapTap(latlng);
          },
        )
        /*body: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: const ll2.LatLng(40.9975, -75.1727),
                  initialZoom: 16.2,
                  onTap: (tapPosition, point) => _onMapTap(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.navigation_app',
                  ),
                  // marker for users current location

                  CurrentLocationLayer(
                    //adding blue marker on map
                    style: const LocationMarkerStyle(

                      markerSize: Size(17, 17),
                      markerDirection: MarkerDirection.heading,
                    ),
                  ),
                  // Dropdown menu
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: BuildingDropdown(
                      onSelected: (selectedLocation) {
                        _handleLocationSelection(selectedLocation); // calling method to turn users selected location into ll2.LatLng points
                        // figure out how to route selected buildings to user
                      },
                    ),
                  ),


                  // 4. Layer for the Route Line
                  if (_routePolyline.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePolyline,
                          color: Colors.blue,
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),

                  // 5. Layer for the Start and End Markers
                  MarkerLayer(
                    markers: [
                      if (_startPoint != null)
                        Marker(
                          point: _startPoint!,
                          child: const Icon(
                              Icons.location_on, color: Colors.green, size: 35),
                        ),
                      if (_endPoint != null)
                        Marker(
                          point: _endPoint!,
                          child: const Icon(
                              Icons.flag, color: Colors.red, size: 35),
                        ),
                    ],
                  ),

                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () =>
                            launchUrl(Uri.parse(
                            'https://openstreetmap.org/copyright')),
                      ),
                    ],
                  ),
                ],
              ),
         */
    );
  }*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('ESU Navigation'),
        backgroundColor: Colors.redAccent,
        actions: [
          if (_startPoint != null || _endPoint != null) // improved check
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _startPoint = null;
                  _endPoint = null;
                  _routePolyline = [];
                });
                //_drawMarkers();
              },
            )
        ],
      ),

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
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              // Optional: Add a subtle background so the text is readable over the map
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
              ),
              child: BuildingDropdown(
                onSelected: (selectedLocation) {
                  _handleLocationSelection(selectedLocation);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
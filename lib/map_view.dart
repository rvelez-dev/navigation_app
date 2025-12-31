import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'campus_dropdown.dart'; // calling dropdown class
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
//import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart' show rootBundle; // Required to load the file
import 'routing_service.dart'; // Ensure this file exists in your lib folder

class MapView extends StatefulWidget {
  const MapView({Key? key}) : super(key: key);

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  // 1. Create the instance
  final RoutingService _routingService = RoutingService();

  // marker of user
  final MapController mapController = MapController();

  // State variables to track navigation
  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _routePolyline = [];
  bool _isGraphLoaded = false;

  bool _useCurrentLocation = false;
  LatLng? _currentUserLocation;

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
        _currentUserLocation = LatLng(userLocation.latitude!, userLocation.longitude!);
      });
      mapController.move(
        LatLng(userLocation.latitude!, userLocation.longitude!),
        17.0, // zoom
      );
      setState(() {}); // refreshes map to show currentLocationLayer
    }
    //location updates and recenter if needed
    _location.onLocationChanged.listen((LocationData newLoc){
      if(newLoc.latitude != null && newLoc.longitude != null){
        _currentUserLocation = LatLng(newLoc.latitude!, newLoc.longitude!);
        if(_useCurrentLocation){
          setState(() {
            _startPoint = _currentUserLocation;
            // If they already picked a destination, update the route live as they walk
            if (_endPoint != null) {
              _routePolyline = _routingService.getRoute(_startPoint!, _endPoint!);
            }
          });
        }
        mapController.move(
          LatLng(newLoc.latitude!, newLoc.longitude!),
          mapController.camera.zoom
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

  // 3. Handle the Tap Logic
  Future<void> _onMapTap(LatLng point) async {
    if (!_isGraphLoaded) return; // Don't allow taps until data is ready

    if (_useCurrentLocation && _currentUserLocation == null) {
      final LocationData forcedLoc = await _location.getLocation();
      if (forcedLoc.latitude != null) {
        setState(() {
          _currentUserLocation = LatLng(forcedLoc.latitude!, forcedLoc.longitude!);
        });
      }
    }

    setState(() {
      //gps is start, tap is always the destination
      if(_useCurrentLocation){
        if(_currentUserLocation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content:  Text("GPS location not found")),
          );
          return;
        }
        //set destination to tap point
        _startPoint = _currentUserLocation;
        _endPoint = point;
        _routePolyline = _routingService.getRoute(_startPoint!, _endPoint!);
      }else{
        //manual start and end select mode
        if (_startPoint == null || (_startPoint != null && _endPoint != null)) {
          // Start fresh: set Point A and clear old route
          _startPoint = point;
          _endPoint = null;
          _routePolyline = [];
        }else{
          // Set Point B and calculate the path
          _endPoint = point;
          _routePolyline = _routingService.getRoute(_startPoint!, _endPoint!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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

        body: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: const LatLng(40.9975, -75.1727),
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
                      onSelected: (building) {
                        print("User selected: $building");
                        // figure out how to route selected buildings to usergit
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




    );
  }
}
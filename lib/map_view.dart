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
    bool serviceEnabled = await _location.serviceEnabled();
    if(!serviceEnabled){
      serviceEnabled = await _location.requestService();
      if(!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if(permissionGranted == PermissionStatus.denied){
      permissionGranted = await _location.requestPermission();
      if(permissionGranted != PermissionStatus.granted)return;
    }

    //Getting current location and move map accordingly
    final LocationData userLocation = await _location.getLocation();
    if(userLocation.latitude !=null && userLocation.longitude != null){
      mapController.move(
        LatLng(userLocation.latitude!, userLocation.longitude!),
        17.0, // zoom
      );
      setState(() {}); // refreshes map to show currentLocationLayer
    }
    //location updates and recenter if needed
    _location.onLocationChanged.listen((LocationData newLoc){
      if(newLoc.latitude != null && newLoc.longitude != null){
        mapController.move(
          LatLng(newLoc.latitude!, newLoc.longitude!),
          mapController.camera.zoom
        );
      }
    });
  }

  // 3. Handle the Tap Logic
  void _onMapTap(LatLng point) {
    if (!_isGraphLoaded) return; // Don't allow taps until data is ready

    setState(() {
      if (_startPoint == null || (_startPoint != null && _endPoint != null)) {
        // Start fresh: set Point A and clear old route
        _startPoint = point;
        _endPoint = null;
        _routePolyline = [];
      } else {
        // Set Point B and calculate the path
        _endPoint = point;
        _routePolyline = _routingService.getRoute(_startPoint!, _endPoint!);
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




    );
  }
}
import 'dart:math';
import 'package:latlong2/latlong.dart' as ll2;
import 'campus_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'routing_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'building_info.dart';
import 'buildings.dart';
import 'building_hit_tester.dart';
import 'walking_time_calculator.dart';
import 'map_layer_service.dart';
import 'package:flutter/services.dart' show rootBundle;

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  // Services — pure-logic helpers the widget delegates to.
  final RoutingService _routingService = RoutingService();
  final BuildingHitTester _hitTester = BuildingHitTester();
  final MapLayerService _layerService = MapLayerService();

  // Map controller and routing/navigation state.
  MapLibreMapController? mapController;

  ll2.LatLng? _startPoint;
  ll2.LatLng? _endPoint;
  List<ll2.LatLng> _routePolyline = [];

  String _walkingTimeEstimate = '';

  bool _showBlueDot = false;
  bool _autoCenter = true;
  ll2.LatLng? _currentUserLocation;

  String? _selectedDestinationName;
  bool _isRouting = false;
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();

  // -------------------------------------------------------------------------
  // Location & timers.
  // -------------------------------------------------------------------------
  final Location _location = Location();

  Timer? _locationUpdateTimer;
  Timer? _routeUpdateTimer;
  Timer? _rerouteTimer;
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isAddingRoute = false;

  // Route line animation.
  Timer? _animationTimer;
  double _dashOffset = 0;
  bool _routeLayerExists = false;

  // Tap-vs-drag detection on the map.
  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _routeUpdateTimer?.cancel();
    _locationSubscription?.cancel();
    _animationTimer?.cancel();
    _rerouteTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAsync() async {
    await Future.wait([
      _initializeRouting(),
      _requestLocationPermissionAndCenter(),
      _hitTester.loadFromAssets(const [
        'assets/esu_jsons/campusbuildings.geojson',
        'assets/esu_jsons/apartments.geojson',
        'assets/esu_jsons/dorms.geojson',
      ]),
    ]);
    debugPrint('Loaded ${_hitTester.polygonCount} building polygons');
  }

  Future<void> _initializeRouting() async {
    try {
      final String geoJsonData = await rootBundle
          .loadString('assets/esu_jsons/walkways.geojson');
      _routingService.loadGeoJson(geoJsonData);

      debugPrint('graph loaded successfully');
    } catch (e) {
      debugPrint('Error loading GeoJSON: $e');
    }
  }

  Future<void> _requestLocationPermissionAndCenter() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 3000,
      distanceFilter: 5,
    );

    final LocationData userLocation = await _location.getLocation();
    if (userLocation.latitude != null && userLocation.longitude != null) {
      if (mounted) {
        setState(() {
          _currentUserLocation =
              ll2.LatLng(userLocation.latitude!, userLocation.longitude!);
        });
      }

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(userLocation.latitude!, userLocation.longitude!),
          mapController?.cameraPosition?.zoom ?? 17.0,
        ),
      );
    }

    _locationSubscription =
        _location.onLocationChanged.listen((LocationData newLoc) {
          if (newLoc.latitude != null && newLoc.longitude != null) {
            _handleLocationUpdate(newLoc);
          }
        });
  }

  void _handleLocationUpdate(LocationData newLoc) {
    _locationUpdateTimer?.cancel();

    _currentUserLocation = ll2.LatLng(newLoc.latitude!, newLoc.longitude!);

    _locationUpdateTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      bool needsUpdate = true;
      _startPoint = _currentUserLocation;

      if (_endPoint != null) {
        _scheduleRouteUpdate();
      }

      if (_autoCenter) {
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(newLoc.latitude!, newLoc.longitude!),
            mapController?.cameraPosition?.zoom ?? 17.0,
          ),
        );
      }
      if (needsUpdate && mounted) {
        setState(() {});
      }
    });
  }

  void _scheduleRouteUpdate() {
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_startPoint != null && _endPoint != null && mounted) {
        final newRoute = _routingService.getRoute(_startPoint!, _endPoint!);
        if (mounted) {
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
        debugPrint('reroute timer: not routing');
        return;
      }
      if (_currentUserLocation == null || _endPoint == null) {
        debugPrint('reroute timer: missing location or endpoint');
        return;
      }
      _startPoint = _currentUserLocation;
      _makePath(_startPoint!, _endPoint!);
      debugPrint('Reroute tick — $_currentUserLocation to $_endPoint');
    });
  }

  void _stopRerouteTimer() {
    _rerouteTimer?.cancel();
    _rerouteTimer = null;
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;
    }

    if (permissionGranted == PermissionStatus.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permission is permanently denied. Please enable it in settings.')),
        );
      }
      return false;
    }

    return true;
  }

  void _tiltAndRotateCamera(ll2.LatLng start, ll2.LatLng destination) {
    if (mapController == null) return;

    const ll2.Distance distance = ll2.Distance();
    final double bearing = distance.bearing(start, destination);

    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(start.latitude, start.longitude),
          tilt: 60.0,
          zoom: 17.5,
          bearing: bearing,
        ),
      ),
      duration: const Duration(milliseconds: 1500),
    );
  }

  // Routing — draws the path on the map and updates state.
  void _makePath(ll2.LatLng start, ll2.LatLng end) {
    debugPrint('Calling routing service');
    final path = _routingService.getRoute(start, end);

    if (mounted) {
      setState(() {
        _routePolyline = path;
        _walkingTimeEstimate = WalkingTimeCalculator.estimate(path);
      });
    }
    _updateRouteGeometry(_routePolyline);
  }

  Future<void> addRouteLayer(List<ll2.LatLng> points) async {
    if (mapController == null || points.isEmpty) return;
    if (_isAddingRoute) return;
    _isAddingRoute = true;

    _stopRouteAnimation();

    try { await mapController!.removeLayer('animated-route'); } catch (_) {}
    try { await mapController!.removeLayer('route-layer'); } catch (_) {}
    try { await mapController!.removeSource('route-source'); } catch (_) {}
    await mapController!.clearLines();

    final List<List<double>> coords =
    points.map((p) => [p.longitude, p.latitude]).toList();

    final Map<String, dynamic> geojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coords,
          },
        }
      ],
    };

    try {
      if (_routeLayerExists) {
        try { await mapController!.removeLayer('animated-route'); } catch (_) {}
        try { await mapController!.removeSource('route-source'); } catch (_) {}
        _routeLayerExists = false;
      }

      await mapController!.clearLines();

      await mapController!.addSource(
        'route-source',
        GeojsonSourceProperties(data: geojson),
      );

      await mapController!.addLayer(
        'route-source',
        'animated-route',
        LineLayerProperties(
          lineColor: '#FF0000',
          lineWidth: 5.0,
          lineOpacity: 0.9,
          lineCap: 'round',
          lineJoin: 'round',
          lineDasharray: [2, 2],
        ),
      );

      _routeLayerExists = true;
      _startRouteAnimation();
    } catch (e) {
      debugPrint('Caught map error in addRouteLayer: $e');
    } finally {
      _isAddingRoute = false;
    }
  }

  void _startRouteAnimation() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || mapController == null || !_routeLayerExists) return;

      _dashOffset = (_dashOffset + 0.5) % 4.0;
      final double t = _dashOffset;
      mapController!.setLayerProperties(
        'animated-route',
        LineLayerProperties(
          lineDasharray: [t, 4.0 - t, 2.0, 2.0],
        ),
      );
    });
  }

  void _stopRouteAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  Future<void> _startRouting() async {
    if (_currentUserLocation == null) {
      bool hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permission is required to start navigation.')),
        );
        return;
      }

      try {
        final LocationData freshLoc = await _location
            .getLocation()
            .timeout(const Duration(seconds: 5));
        if (freshLoc.latitude != null && freshLoc.longitude != null) {
          _currentUserLocation =
              ll2.LatLng(freshLoc.latitude!, freshLoc.longitude!);

          _locationSubscription ??=
              _location.onLocationChanged.listen((LocationData newLoc) {
                if (newLoc.latitude != null && newLoc.longitude != null) {
                  _handleLocationUpdate(newLoc);
                }
              });
        }
      } catch (e) {
        debugPrint('Failed to get location: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not get your location. Please try again.')),
        );
        return;
      }
    }

    _startPoint = _currentUserLocation;

    if (_startPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still waiting for GPS signal...')),
      );
      return;
    }

    setState(() {
      _isRouting = true;
    });

    _makePath(_startPoint!, _endPoint!);
    _tiltAndRotateCamera(_startPoint!, _endPoint!);

    _sheetController.animateTo(
      0.15,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _startRerouteTimer();
  }

  Future<void> _updateRouteGeometry(List<ll2.LatLng> points) async {
    if (mapController == null || points.isEmpty) return;

    final List<List<double>> coords =
    points.map((p) => [p.longitude, p.latitude]).toList();

    final Map<String, dynamic> geojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coords,
          },
        }
      ],
    };

    try {
      if (_routeLayerExists) {
        await mapController!.setGeoJsonSource('route-source', geojson);
      } else {
        await addRouteLayer(points);
      }
    } catch (e) {
      debugPrint('Error updating route geometry: $e');
    }
  }

  Future<void> _addDestinationMarker(ll2.LatLng location) async {
    if (mapController == null) return;

    try {
      final layers = await mapController!.getLayerIds();
      if (layers.contains('destination-pin')) {
        await mapController!.removeLayer('destination-pin');
      }
      if (layers.contains('endpoint_logo')) {
        await mapController!.removeLayer('endpoint_logo');
      }
    } catch (e) {
      debugPrint('Error removing destination layers: $e');
    }

    try {
      final sources = await mapController!.getSourceIds();
      if (sources.contains('destination-source')) {
        await mapController!.removeSource('destination-source');
      }
    } catch (e) {
      debugPrint('Error removing destination source: $e');
    }

    await mapController?.addSource(
      'destination-source',
      GeojsonSourceProperties(data: {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [location.longitude, location.latitude],
            },
          }
        ],
      }),
    );

    await mapController?.addCircleLayer(
      'destination-source',
      'destination-pin',
      const CircleLayerProperties(
        circleColor: '#FF0000',
        circleRadius: 12,
        circleStrokeWidth: 3,
        circleStrokeColor: '#FFFFFF',
        circleOpacity: 1.0,
      ),
    );
    await mapController?.addSymbolLayer(
      'destination-source',
      'endpoint_logo',
      SymbolLayerProperties(
        iconImage: 'warrior_logo',
        iconSize: 0.35,
        iconAnchor: 'bottom',
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
      _isRouting = false;
      _routePolyline = [];
      _walkingTimeEstimate = '';
    });
    _stopRerouteTimer();

    if (mapController != null) {
      mapController!.clearLines();
    }

    _addDestinationMarker(_endPoint!);

    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_endPoint!.latitude, _endPoint!.longitude),
        17.5,
      ),
    );

    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _clearDestination() async {
    _stopRerouteTimer();
    _routeUpdateTimer?.cancel();
    _stopRouteAnimation();

    if (mapController != null) {
      try { await mapController!.removeLayer('animated-route'); } catch (_) {}
      try { await mapController!.removeLayer('route-layer'); } catch (_) {}
      try { await mapController!.removeSource('route-source'); } catch (_) {}
      try { await mapController!.removeLayer('destination-pin'); } catch (_) {}
      try { await mapController!.removeLayer('endpoint_logo'); } catch (_) {}
      try { await mapController!.removeSource('destination-source'); } catch (_) {}
    }
    _routeLayerExists = false;

    if (mounted) {
      setState(() {
        _selectedDestinationName = null;
        _endPoint = null;
        _isRouting = false;
        _routePolyline = [];
        _walkingTimeEstimate = '';
      });
    }
  }

  // Style-loaded callback — delegates layer setup to MapLayerService.
  void _onStyleLoaded() async {
    if (mapController == null) return;

    final layers = await mapController!.getLayerIds();
    debugPrint('All map layers: $layers');

    await _layerService.addImageFromAsset(
        mapController!, 'warrior_logo', 'assets/images/esu_warrior_logo.png');
    await _layerService.addImageFromAsset(
        mapController!, 'info_icon', 'assets/images/info_icon.png');

    try {
      await Future.wait([
        _layerService.addGrassLayer(mapController!),
        _layerService.addTreeLayer(mapController!),
        _layerService.add3DBuildingsLayer(mapController!),
        _layerService.addLabelsLayer(mapController!),
      ]);
    } catch (e) {
      debugPrint('Error during layer initialization: $e');
    }

    PermissionStatus permissionStatus = await _location.hasPermission();
    if (permissionStatus == PermissionStatus.granted && mounted) {
      await mapController?.updateMyLocationTrackingMode(
          MyLocationTrackingMode.none);
      debugPrint('Blue dot engine started.');
      setState(() {
        _showBlueDot = true;
      });
    } else {
      debugPrint('Location permission not granted yet — blue dot suppressed');
    }
  }

  // UI building helpers.
  Widget _buildAboutSection() {
    if (_selectedDestinationName == null) return const SizedBox.shrink();

    final BuildingInfo? info = buildingData[_selectedDestinationName];
    if (info == null) {
      return const Text('ℹ️ No details available for this location yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(info.description,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        const Text('Hours:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...info.formattedHours.map((line) => Text(line)),
      ],
    );
  }

  Widget _buildImageGallery(List<String> imagePaths) {
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imagePaths.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 340,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    imagePaths[index],
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Renders the "Related locations" section for buildings that have linked
  // alt locations (e.g. Hawthorn ↔ RecB Fitness Center). Returns an empty
  // widget when there are no links, so it's safe to call unconditionally.
  Widget _buildRelatedLocationsSection() {
    if (_selectedDestinationName == null) return const SizedBox.shrink();

    final BuildingInfo? info = buildingData[_selectedDestinationName];
    final List<String>? alts = info?.altLocations;
    if (alts == null || alts.isEmpty) return const SizedBox.shrink();

    // Filter out any links that point to non-existent entries so a stale
    // reference can't crash the UI. The debug verifier catches these at boot.
    final List<String> validAlts =
    alts.where((name) => buildingData.containsKey(name)).toList();
    if (validAlts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          'Related Locations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
            shadows: [
              Shadow(
                color: Colors.black,
                offset: Offset(0, 0),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const Divider(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: validAlts.map((altName) {
            return OutlinedButton.icon(
              onPressed: () => _handleLocationSelection(altName),
              icon: const Icon(Icons.place_outlined, size: 18),
              label: Text(altName),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Listener(
            onPointerDown: (PointerDownEvent event) {
              _pointerDownPosition = event.localPosition;
              _pointerDownTime = DateTime.now();
            },
            onPointerUp: (PointerUpEvent event) async {
              if (_pointerDownPosition == null || mapController == null) return;

              final distance =
                  (event.localPosition - _pointerDownPosition!).distance;
              final elapsed = DateTime.now().difference(_pointerDownTime!);
              if (elapsed.inMilliseconds > 300 || distance > 10.0) return;

              final dpr = MediaQuery.of(context).devicePixelRatio;
              final screenPoint = Point<double>(
                event.localPosition.dx * dpr,
                event.localPosition.dy * dpr,
              );

              final LatLng mapPoint = await mapController!.toLatLng(screenPoint);
              final convertedPoint =
              ll2.LatLng(mapPoint.latitude, mapPoint.longitude);

              // ---- Delegated to BuildingHitTester ----
              final tappedBuilding = _hitTester.findBuildingAt(convertedPoint);

              if (tappedBuilding != null) {
                debugPrint('Hit building: $tappedBuilding');
                _handleLocationSelection(tappedBuilding);
              } else {
                debugPrint('No building at tap location');
              }
            },
            child: MapLibreMap(
              cameraTargetBounds: CameraTargetBounds(LatLngBounds(
                southwest: const LatLng(40.99203, -75.17833),
                northeast: const LatLng(40.9997558, -75.1597061),
              )),
              minMaxZoomPreference: const MinMaxZoomPreference(14.0, 21.0),
              myLocationEnabled: _showBlueDot,
              myLocationRenderMode: MyLocationRenderMode.normal,
              myLocationTrackingMode: MyLocationTrackingMode.none,
              styleString: 'https://tiles.openfreemap.org/styles/bright',
              initialCameraPosition: const CameraPosition(
                target: LatLng(40.9959155, -75.173446),
                zoom: 17.0,
                tilt: 60,
              ),
              onMapCreated: (controller) => mapController = controller,
              onStyleLoadedCallback: _onStyleLoaded,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
          ),
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
          if (_showBlueDot)
            Positioned(
              bottom: 100,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'gps_toggle_fab',
                mini: true,
                backgroundColor: _autoCenter ? Colors.blue : Colors.white,
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _autoCenter = !_autoCenter;
                    });
                  }

                  if (_autoCenter && _currentUserLocation != null) {
                    mapController?.animateCamera(
                      CameraUpdate.newLatLng(
                        LatLng(_currentUserLocation!.latitude,
                            _currentUserLocation!.longitude),
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
              initialChildSize: 0.3,
              minChildSize: 0.1,
              maxChildSize: 0.9,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2)
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDestinationName!,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _clearDestination,
                                tooltip: 'Close',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          if (buildingData[_selectedDestinationName] != null)
                            Text(
                              buildingData[_selectedDestinationName]!
                                  .openStatus
                                  .label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: buildingData[_selectedDestinationName]!
                                    .openStatus
                                    .color,
                              ),
                            ),
                          const SizedBox(height: 15),
                          _buildImageGallery(
                              buildingData[_selectedDestinationName]!.imagePaths),
                          if (!_isRouting && _walkingTimeEstimate.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.directions_walk,
                                    size: 18, color: Colors.blue),
                                const SizedBox(width: 6),
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
                          else if (!_isRouting)
                            Row(
                              children: [
                                Icon(Icons.directions_walk,
                                    size: 18, color: Colors.grey[400]),
                                const SizedBox(width: 6),
                                Text(
                                  'Tap "Start Route" to see walk time',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[400],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 15),
                          if (!_isRouting)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _startRouting,
                                icon: const Icon(Icons.directions_walk),
                                label: const Text('Start Route',
                                    style: TextStyle(fontSize: 18)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            )
                          else
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Navigating...',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 30),
                          const Text(
                            'About This Building',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 0),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          _buildAboutSection(),
                          _buildRelatedLocationsSection(),
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
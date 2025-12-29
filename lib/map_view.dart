import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // State variables to track navigation
  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _routePolyline = [];
  bool _isGraphLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeRouting();
  }

  // 2. Load the GeoJSON file into the service
  Future<void> _initializeRouting() async {
    try {
      final String geoJsonData = await rootBundle.loadString('assets/esu_jsons/walkways.geojson');
      _routingService.loadGeoJson(geoJsonData);
      setState(() {
        _isGraphLoaded = true;
      });
    } catch (e) {
      debugPrint("Error loading GeoJSON: $e");
    }
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
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('ESU Navigation'),
        backgroundColor: Colors.redAccent,
        actions: [
          if (_startPoint != null)
            IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() { _startPoint = null; _endPoint = null; _routePolyline = []; })
            )
        ],
      ),
      body: FlutterMap(
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
                  child: const Icon(Icons.location_on, color: Colors.green, size: 35),
                ),
              if (_endPoint != null)
                Marker(
                  point: _endPoint!,
                  child: const Icon(Icons.flag, color: Colors.red, size: 35),
                ),
            ],
          ),

          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Owns the work of adding decorative and informational layers to the map:
/// grass, trees, 3D buildings, building labels, and image assets.
///
/// Takes the [MapLibreMapController] as a parameter on each call rather than
/// storing it — this keeps the service stateless and avoids dangling refs
/// if the map gets rebuilt.
class MapLayerService {
  /// Adds an image asset to the map under [name] for use in symbol layers.
  Future<void> addImageFromAsset(
    MapLibreMapController controller,
    String name,
    String assetName,
  ) async {
    final ByteData bytes = await rootBundle.load(assetName);
    final Uint8List list = bytes.buffer.asUint8List();
    return controller.addImage(name, list);
  }

  /// Adds the 3D building extrusion layer using the OpenMapTiles building data.
  Future<void> add3DBuildingsLayer(MapLibreMapController controller) async {
    // Defensively remove in case of a hot-reload partial state.
    try {
      await controller.removeLayer('3d-buildings');
    } catch (e) { debugPrint('Error removing 3D buildings layer: $e'); }
    try {
      await controller.removeSource('campus-buildings-source');
    } catch (e) { debugPrint('Error removing buildings source: $e'); }

    try {
      // Load and merge the three building files into one FeatureCollection.
      final String campusJson = await rootBundle.loadString('assets/esu_jsons/campusbuildings.geojson');
      final String dormsJson = await rootBundle.loadString('assets/esu_jsons/dorms.geojson');
      final String apartmentsJson = await rootBundle.loadString('assets/esu_jsons/apartments.geojson');

      final List<dynamic> mergedFeatures = [
        ...(json.decode(campusJson)['features'] as List),
        ...(json.decode(dormsJson)['features'] as List),
        ...(json.decode(apartmentsJson)['features'] as List),
      ];

      final Map<String, dynamic> mergedData = {
        'type': 'FeatureCollection',
        'features': mergedFeatures,
      };

      await controller.addSource(
        'campus-buildings-source',
        GeojsonSourceProperties(data: mergedData),
      );

      await controller.addLayer(
        'campus-buildings-source',
        '3d-buildings',
        FillExtrusionLayerProperties(
          fillExtrusionColor: '#F0EBE1',
          fillExtrusionHeight: 10,
          fillExtrusionBase: 0,
          fillExtrusionOpacity: 0.9,
          fillExtrusionVerticalGradient: true,
        ),
        belowLayerId: 'building-labels-display-layer',
      );
      debugPrint('3D buildings layer added successfully');
    } catch (e) {
      debugPrint('Error adding 3D buildings layer: $e');
    }
  }

  /// Adds the symbol layer that draws building name labels at fixed points.
  Future<void> addLabelsLayer(MapLibreMapController controller) async {
    try {
      await controller.addSource(
        'building-labels-source',
        GeojsonSourceProperties(data: _buildingLabelsData),
      );

      await controller.addSymbolLayer(
        'building-labels-source',
        'building-labels-display-layer',
        SymbolLayerProperties(
          textField: ['get', 'name'],
          textColor: '#333333',
          textFont: ['Noto Sans Regular'],
          textTransform: 'uppercase',
          textLetterSpacing: 0.1,
          textSize: [
            'interpolate',
            ['linear'],
            ['zoom'],
            15, 10.0,
            18, 14.0,
          ],
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.5,
          textHaloBlur: 0.5,
          textAllowOverlap: true,
        ),
      );
      debugPrint('Building labels layer added successfully');
    } catch (e) {
      debugPrint('Error in addLabelsLayer: $e');
    }
  }

  /// Adds the green grass fill layer below the building layer.
  Future<void> addGrassLayer(MapLibreMapController controller) async {
    try {
      final String grassJson =
          await rootBundle.loadString('assets/esu_jsons/grass.geojson');
      final Map<String, dynamic> grassData = json.decode(grassJson);

      await controller.addSource(
        'grass-source',
        GeojsonSourceProperties(data: grassData),
      );

      await controller.addFillLayer(
        'grass-source',
        'grass-layer',
        const FillLayerProperties(
          fillColor: '#BEE7A5',
          fillOpacity: 0.5,
        ),
        belowLayerId: 'building',
      );
      debugPrint('Grass layer added successfully');
    } catch (e) {
      debugPrint('Error adding grass layer: $e');
    }
  }

  /// Adds two extrusion layers (canopy + trunk) to render trees in 3D.
  Future<void> addTreeLayer(MapLibreMapController controller) async {
    try {
      final String canopyJson =
          await rootBundle.loadString('assets/esu_jsons/trees.geojson');
      final String trunkJson =
          await rootBundle.loadString('assets/esu_jsons/treetrunks.geojson');
      final Map<String, dynamic> canopyData = json.decode(canopyJson);
      final Map<String, dynamic> trunkData = json.decode(trunkJson);

      await controller.addSource(
        'tree-canopy-source',
        GeojsonSourceProperties(data: canopyData),
      );
      await controller.addSource(
        'tree-trunk-source',
        GeojsonSourceProperties(data: trunkData),
      );

      await controller.addLayer(
        'tree-canopy-source',
        'tree-canopy-layer',
        FillExtrusionLayerProperties(
          fillExtrusionColor: '#77a37a',
          fillExtrusionHeight: 6.25,
          fillExtrusionBase: 2.5,
          fillExtrusionOpacity: 0.95,
          fillExtrusionVerticalGradient: true,
        ),
        belowLayerId: 'building-labels-display-layer',
      );

      await controller.addLayer(
        'tree-trunk-source',
        'tree-trunk-layer',
        FillExtrusionLayerProperties(
          fillExtrusionColor: '#3B1F0A',
          fillExtrusionHeight: 3.5,
          fillExtrusionBase: 0.0,
          fillExtrusionOpacity: 0.95,
          fillExtrusionVerticalGradient: true,
        ),
        belowLayerId: 'building-labels-display-layer',
      );
      debugPrint('Tree layers added successfully');
    } catch (e) {
      debugPrint('Error adding tree layer: $e');
    }
  }

  // Static label data
  static const Map<String, dynamic> _buildingLabelsData = {
    'type': 'FeatureCollection',
    'features': [
      {'type': 'Feature', 'properties': {'name': 'Eiler-Martin Stadium'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1727, 40.9936]}},
      {'type': 'Feature', 'properties': {'name': 'Dansbury Commons'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1736, 40.9970]}},
      {'type': 'Feature', 'properties': {'name': 'Flagler-Metzgar Center'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1729, 40.9970]}},
      {'type': 'Feature', 'properties': {'name': 'Monroe Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1727, 40.9951]}},
      {'type': 'Feature', 'properties': {'name': 'Koehler Fieldhouse and Natatorium'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1703, 40.9968]}},
      {'type': 'Feature', 'properties': {'name': 'Kemp Library'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1701, 40.9984]}},
      {'type': 'Feature', 'properties': {'name': 'Mattioli Recreation Center'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1701, 40.9953]}},
      {'type': 'Feature', 'properties': {'name': 'Beers Lecture Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1749, 40.9955]}},
      {'type': 'Feature', 'properties': {'name': 'Reibman Administration Building'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1768, 40.9957]}},
      {'type': 'Feature', 'properties': {'name': 'Moore Biology Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1749, 40.9965]}},
      {'type': 'Feature', 'properties': {'name': 'Gessner'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1751, 40.9958]}},
      {'type': 'Feature', 'properties': {'name': 'Sci-Tech Center'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1758, 40.9965]}},
      {'type': 'Feature', 'properties': {'name': 'Stroud Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1741, 40.99545]}},
      {'type': 'Feature', 'properties': {'name': 'University Center'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1738, 40.9961]}},
      {'type': 'Feature', 'properties': {'name': 'University Center (soon)'}, 'geometry': {'type': 'Point', 'coordinates': [-75.17363, 40.99553]}},
      {'type': 'Feature', 'properties': {'name': 'Laurel Residence Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1730, 40.9961]}},
      {'type': 'Feature', 'properties': {'name': 'Shawnee Residence Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1720, 40.9960]}},
      {'type': 'Feature', 'properties': {'name': 'Minsi Residence Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1718, 40.9954]}},
      {'type': 'Feature', 'properties': {'name': 'Linden Residence Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1711, 40.9961]}},
      {'type': 'Feature', 'properties': {'name': 'Hemlock Suites'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1713, 40.9978]}},
      {'type': 'Feature', 'properties': {'name': 'Lenape Residence Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1720, 40.9986]}},
      {'type': 'Feature', 'properties': {'name': 'Hawthorn Suites'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1727, 40.9991]}},
      {'type': 'Feature', 'properties': {'name': 'Sycamore Suites'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1722, 40.9974]}},
      {'type': 'Feature', 'properties': {'name': 'Abeloff'}, 'geometry': {'type': 'Point', 'coordinates': [-75.175136, 40.994328]}},
      {'type': 'Feature', 'properties': {'name': 'Wess 90.3 Radio'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1738, 40.9949]}},
      {'type': 'Feature', 'properties': {'name': 'Zimbar-Liljenstein Hall'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1735, 40.9938]}},
      {'type': 'Feature', 'properties': {'name': 'Rosenkrans'}, 'geometry': {'type': 'Point', 'coordinates': [-75.174627, 40.994553]}},
      {'type': 'Feature', 'properties': {'name': 'DeNike'}, 'geometry': {'type': 'Point', 'coordinates': [-75.17602, 40.994049]}},
      {'type': 'Feature', 'properties': {'name': 'Innovation Center'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1783, 40.9946]}},
      {'type': 'Feature', 'properties': {'name': 'Facilities Management'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1768, 40.9975]}},
      {'type': 'Feature', 'properties': {'name': 'University Ridge'}, 'geometry': {'type': 'Point', 'coordinates': [-75.1834, 40.9900]}},
      {'type': 'Feature', 'properties': {'name': 'Fine and Performing Arts'}, 'geometry': {'type': 'Point', 'coordinates': [-75.166295, 40.998738]}},
    ],
  };
}

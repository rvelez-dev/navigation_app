# ESU Campus Navigator

An Android app for navigating East Stroudsburg University's campus — built with Flutter by Jaden Randolph and Rachel Velez.

The app renders an interactive campus map and helps students find buildings, dorms, and parking, then walks them there turn-by-turn along real campus walkways instead of just drawing a straight line.

## Features

- **Interactive campus map** — buildings, dorms, apartments, parking lots/aisles, roads, walkways, grass, and trees are rendered as individual layers from GeoJSON data ([assets/esu_jsons/](assets/esu_jsons/)).
- **Walkway-aware routing** — campus walkways are loaded into a graph and the shortest path between two points is computed with Dijkstra's algorithm, so routes follow actual sidewalks and paths ([lib/routing_service.dart](lib/routing_service.dart)).
- **Walking time estimates** — each route shows an estimated walk time and distance ([lib/walking_time_calculator.dart](lib/walking_time_calculator.dart)).
- **Building info panel** — tap a building to see its description, hours of operation, facilities, and photos ([lib/building_info.dart](lib/building_info.dart), [lib/building_hit_tester.dart](lib/building_hit_tester.dart)).
- **Search / campus dropdown** — quickly find a building or location by name ([lib/campus_dropdown.dart](lib/campus_dropdown.dart)).
- **Live location** — shows the user's current position on the map and can route from it using on-device GPS ([lib/getLocation/modify_location.dart](lib/getLocation/modify_location.dart)).

## Tech Stack

- [Flutter](https://flutter.dev/) / Dart
- [flutter_map](https://pub.dev/packages/flutter_map) + [maplibre_gl](https://pub.dev/packages/maplibre_gl) for map rendering
- [dijkstra](https://pub.dev/packages/dijkstra) for shortest-path routing over the walkway graph
- [geolocator](https://pub.dev/packages/geolocator) / [location](https://pub.dev/packages/location) for device positioning
- [turf](https://pub.dev/packages/turf) for geospatial helpers
- GeoJSON for all campus map data (buildings, walkways, roads, parking, dorms, etc.)

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.10.4`)
- Android Studio / an Android device or emulator

### Run it

```bash
flutter pub get
flutter run
```

### Tests

```bash
flutter test
```

## Project Structure

```
lib/
├── main.dart                     # App entry point
├── map_view.dart                 # Main map screen
├── map_layer_service.dart        # Loads/renders GeoJSON map layers
├── routing_service.dart          # Walkway graph + Dijkstra routing
├── walking_time_calculator.dart  # Route distance/time estimation
├── buildings.dart                # Building data model/registry
├── building_info.dart            # Building details (hours, facilities, photos)
├── building_hit_tester.dart      # Tap-to-select building detection
├── campus_dropdown.dart          # Building search/select UI
└── getLocation/
    └── modify_location.dart      # Device location handling

assets/
├── esu_jsons/                    # Campus GeoJSON data (buildings, walkways, parking, etc.)
└── images/                       # App icons and building photos
```

## Data

Campus geometry (buildings, dorms, apartments, walkways, roads, parking lots/aisles, grass, and trees) lives in [assets/esu_jsons/](assets/esu_jsons/) as GeoJSON, sourced and maintained for ESU's campus.

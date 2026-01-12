
import 'package:flutter/material.dart';
import 'map_view.dart'; //map view for app
//new imports for geojsons

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, //removes "demo" tag
      title: 'Navigation ',
      theme: ThemeData(

        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MapView(),
    );
  }
}

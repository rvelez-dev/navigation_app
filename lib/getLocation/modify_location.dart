import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ModifyLocation extends StatefulWidget {
  const ModifyLocation({super.key});

  @override
  State<ModifyLocation> createState() => _ModifyLocationState();
}

class _ModifyLocationState extends State<ModifyLocation> {

  String _latitude = 'Latitude:';
  String _longitude = 'Longitude:';

  Future<void> fetchCurrentPosition() async
  {
    try
    {
      Position currentposition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _latitude = 'Latitude: ${currentposition.latitude}';
        _longitude = 'Latitude: ${currentposition.longitude}';
      });
    }
    catch (error)
    {
      debugPrint('Error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigation "),
        flexibleSpace: Container( //changes the top header
          color: Colors.redAccent
        ),
        centerTitle: true, // centers title of app
      ),
      body:Container( // changes the body of the app
        decoration: BoxDecoration(
          color: Colors.black26,
              //begin: Alignment.topLeft,
              //end: Alignment.bottomRight,
          ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: (){
                    fetchCurrentPosition();
                  },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Get Location'),
              ),
              const SizedBox(height:20,),
              Text(
                _latitude,
                style:TextStyle(fontSize: 20),
              ),
              const SizedBox(height:20,),
              Text(
                _longitude,
                style:TextStyle(fontSize: 20),
              ),
            ],
          )
        )
        ),
      );
  }
}

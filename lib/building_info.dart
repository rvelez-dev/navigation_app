import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll2;

class OperationHours {
  TimeOfDay openTime;
  TimeOfDay closeTime;

  OperationHours(this.openTime, this.closeTime);
}

class BuildingInfo {
  String _name;
  String _description;
  List<OperationHours> _hours;
  List<String> _facilities;
  List<String> _imagePaths;
  List<String>? _poi;//points of interest for composite buildings
  ll2.LatLng _location;

  // Constructor
  BuildingInfo({
    required String name,
    required String description,
    required List<OperationHours> hours,
    required List<String> facilities,
    required List<String> imagePaths,
    required ll2.LatLng location,
    List<String>? poi
  })  : _name = name,
        _description = description,
        _hours = hours,
        _facilities = facilities,
        _imagePaths = imagePaths,
        _location = location,
        _poi = poi;


  // Getters
  String get name => _name;

  String get description => _description;

  List<OperationHours> get hours => _hours;

  List<String> get facilities => _facilities;

  List<String> get imagePaths => _imagePaths;

  List<String>? get poi => _poi;

  ll2.LatLng get location => _location;

  // Method to check if the building is open

  bool get isOpen {
    TimeOfDay now = TimeOfDay.now();
    int index = DateTime.now().weekday - 1;
    OperationHours todaysHours = _hours[index];

    int nowMins  = now.hour * 60 + now.minute;
    int openMins = todaysHours.openTime.hour  * 60 + todaysHours.openTime.minute;
    int closeMins= todaysHours.closeTime.hour * 60 + todaysHours.closeTime.minute;

    return nowMins > openMins && nowMins < closeMins;
  }
  // Setter example
  /*set description(String value) {
    if (value.isNotEmpty) _description = value;
  }*/

}
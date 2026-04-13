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

  /*bool get isOpen {
    TimeOfDay now = TimeOfDay.now();
    int index = DateTime.now().weekday - 1;
    OperationHours todaysHours = _hours[index];

    int nowMins  = now.hour * 60 + now.minute;
    int openMins = todaysHours.openTime.hour  * 60 + todaysHours.openTime.minute;
    int closeMins= todaysHours.closeTime.hour * 60 + todaysHours.closeTime.minute;

    return nowMins > openMins && nowMins < closeMins;
  }*/
  // Returns the display status and its color based on hoursRemaining
  ({String label, Color color}) get openStatus {
    final hours = hoursRemaining;

    // 24hr or closed-all-day buildings have no meaningful status
    if (hours == 0) {
      return (label: 'Closed', color: Colors.red);
    } else if (hours <= 1) {
      return (label: 'Closing Soon', color: Colors.orange);
    } else {
      return (label: 'Open', color: Colors.green);
    }
  }
  int get hoursRemaining {
    int index = DateTime.now().weekday - 1;
    OperationHours todaysHours = _hours[index];

    int openMins  = todaysHours.openTime.hour  * 60 + todaysHours.openTime.minute;
    int closeMins = todaysHours.closeTime.hour * 60 + todaysHours.closeTime.minute;

    // Both zero means closed all day OR 24hr open — return 0 either way
    if (openMins == 0 && closeMins == 0) return 0;

    TimeOfDay now = TimeOfDay.now();
    int nowMins = now.hour * 60 + now.minute;

    // Before opening or after closing — return 0
    if (nowMins <= openMins || nowMins >= closeMins) return 0;

    // Return full hours remaining, rounded down
    return (closeMins - nowMins) ~/ 60;
  }

  // Formats the 7-day hours list into grouped, human-readable strings
// e.g. ["Mon - Fri: 7:30 AM - 11:00 PM", "Sat: Closed", "Sun: 2:30 PM - 11:00 PM"]
  List<String> get formattedHours {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    List<String> lines = [];

    int i = 0;
    while (i < _hours.length) {
      final current = _hours[i];
      int j = i + 1;

      while (j < _hours.length &&
          _hours[j].openTime.hour == current.openTime.hour &&
          _hours[j].openTime.minute == current.openTime.minute &&
          _hours[j].closeTime.hour == current.closeTime.hour &&
          _hours[j].closeTime.minute == current.closeTime.minute) {
        j++;
      }

      final bool isClosed =
          current.openTime.hour == 0 && current.openTime.minute == 0 &&
              current.closeTime.hour == 0 && current.closeTime.minute == 0;

      final String dayRange = (j - 1 == i) ? days[i] : '${days[i]} - ${days[j - 1]}';
      final String timeRange = isClosed ? 'Closed' : '${_fmtTime(current.openTime)} - ${_fmtTime(current.closeTime)}';

      lines.add('$dayRange: $timeRange');
      i = j;
    }
    return lines;
  }

  static String _fmtTime(TimeOfDay t) {
    final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
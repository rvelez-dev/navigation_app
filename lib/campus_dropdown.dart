
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';

// StatefulWidget class for dropdown
class BuildingDropdown extends StatefulWidget {

  final Function(String)? onSelected;

  const BuildingDropdown({Key? key, this.onSelected}) : super(key: key);

  @override
  State<BuildingDropdown> createState() => _BuildingDropdownState();
}

//class for dropdown menu
class _BuildingDropdownState extends State<BuildingDropdown> {
  //creating arrays for different locations
  final List<String> dorms = [
    'Laurel Residence Hall',
    'Shawnee Residence Hall',
    'Minsi Residence Hall',
    'Linden Residence Hall',
    'Hemlock Suites',
    'Lenape Residence Hall',
    'Hawthorn Suites',
    'Sycamore Suites',
  ];
  final List<String> campusBuildings =[
    'Mattioli Recreation Center',
    'Joseph H. & Mildred E. Beers Lecture Hall',
    'Reibman Administration Building',
    'Conference Services & Multicultural House',
    'Abeloff Center for the Performing Arts',
    'Rosenkrans Hall',
    'University Center',
    'Henry A. Ahnert Jr. Alumni Center',
  ];
  final List<String> academicBuildings =[
    'Monroe Hall',
    'Koehler Fieldhouse and Natatorium',
    'Kemp Library',
    'Warren E. & Sandra Hoeffner Science and Technology Center',
    'Moore Biology Hall',
    'Gessner Science Hall',
    'Stroud Hall',
    'DeNike Center for Human Services',
    'Fine and Performing Arts Center',
    'Zimbar-Liljenstein Hall',
  ];
  final List<String> food =[
    'Dansbury Commons',
  ];
  final List<String> outdoorPlaces =[
    'Eiler-Martin Stadium',
    'Dave Carllyon Pavilion',
  ];
  // Current selection
  String? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(

      hint: const Text("Where To?"),
      value: _selectedLocation,
      isExpanded: true,

      items: dorms.map((dorm) {
        return DropdownMenuItem<String>(
          value: dorm,
          child: Text(
            dorm,
            style: const TextStyle(fontSize: 15),
          ),
        );
      }).toList(),

      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _selectedLocation = value; //selectedlocation in map view
        });

        // Notify MapView
        if (widget.onSelected != null) {
          widget.onSelected!(value);
        }
      },
    );
  }
}
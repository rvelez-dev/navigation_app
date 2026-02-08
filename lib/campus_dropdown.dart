import 'package:flutter/material.dart';

// StatefulWidget class for dropdown
class BuildingDropdown extends StatefulWidget {

  final Function(String)? onSelected;

  const BuildingDropdown({super.key, this.onSelected});

  @override
  State<BuildingDropdown> createState() => _BuildingDropdownState();
}

//class for dropdown menu
class _BuildingDropdownState extends State<BuildingDropdown> {
  //creating list to hold all categories
  final List<String>selectedCategory = [
    'Residence Halls',
    'Campus Buildings',
    'Academic Buildings',
    'Food',
    'Outdoor Spaces & Fields',
  ];


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
  //creating a placeholder list
  late List<String> _currentItems =[];

  @override
  void initState() {
    super.initState();
    _currentItems = selectedCategory;
  }


  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(

      hint: const Text("Where To?"),
      value: _selectedLocation,
      isExpanded: true,


      items: _currentItems.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: const TextStyle(fontSize: 15),
          ),
        );
      }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            // If we are still choosing a category
            if (_currentItems == selectedCategory) {
              _selectedLocation = value;

              if (value == 'Residence Halls') {
                _currentItems = dorms;
              }
              else if (value == 'Campus Buildings') {
                _currentItems = campusBuildings;
              }
              else if (value == 'Academic Buildings') {
                _currentItems = academicBuildings;
              }
              else if (value == 'Food') {
                _currentItems = food;
              }
              /*else if (value == 'Parking Lots') {
          _currentItems = parkingLots;
        }*/
              _selectedLocation = null; // reset selection
            }
            // Otherwise, this is a FINAL destination
            else {
              _selectedLocation = value;
              widget.onSelected?.call(value);
            }
          });
        });
  }
}
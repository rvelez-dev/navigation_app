
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

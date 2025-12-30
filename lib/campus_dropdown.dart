
import 'package:flutter/material.dart';

// StatefulWidget class for dropdown
class BuildingDropdown extends StatefulWidget {

  final Function(String)? onSelected;

  const BuildingDropdown({Key? key, this.onSelected}) : super(key: key);

  @override
  State<BuildingDropdown> createState() => _BuildingDropdownState();
}

//class for dropdown menu
class _BuildingDropdownState extends State<BuildingDropdown> {
  // Current selection
  String? _selectedBuilding;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      hint: const Text("Select a building"), // placeholder text
      value: _selectedBuilding,
      items: [
        // Placeholder options
        DropdownMenuItem(value: "Library", child: Text("Library")),
        DropdownMenuItem(value: "Science Hall", child: Text("Science Hall")),
      ],
      onChanged: (value) {
        setState(() {
          _selectedBuilding = value;
        });

        // Call the callback in MapView if provided
        if (value != null && widget.onSelected != null) {
          widget.onSelected!(value);
        }
      },
    );
  }
}

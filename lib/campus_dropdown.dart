
import 'package:flutter/material.dart';


class MySearchDelegate extends SearchDelegate {
  //callback function that sends the selected location back to map_view
final Function(String) onLocationSelected;

//constructor that requires the callback to be passed in
MySearchDelegate({required this.onLocationSelected});


@override
//supposed to remove side tool bar but i had to change it in settings -- get back to this
TextInputAction get textInputAction => TextInputAction.search;



  //creating list to hold all searchable locations
  final List<String>allCampusLocations= [
    //residence halls
    'Laurel Residence Hall',
    'Shawnee Residence Hall',
    'Minsi Residence Hall',
    'Linden Residence Hall',
    'Hemlock Suites',
    'Lenape Residence Hall',
    'Hawthorn Suites',
    'Sycamore Suites',
    //campus buildings
    'Mattioli Recreation Center',
    'Joseph H. & Mildred E. Beers Lecture Hall',
    'Reibman Administration Building',
    'Conference Services & Multicultural House',
    'Abeloff Center for the Performing Arts',
    'Rosenkrans Hall',
    'University Center',
    'Henry A. Ahnert Jr. Alumni Center',
    //academic buildings
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
    //food
    'Dansbury Commons',
    //outdoor places
    'Eiler-Martin Stadium',
    'Dave Carllyon Pavilion',
  ];


  @override
  //this widget builds the (X) button on the right side of the search bar to clear
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear),
      onPressed: (){
        if(query.isEmpty){// of field is empty
          close(context,null); //close searchbar
        }else{
          query =''; // if there is a text clear it
        }
      },
    ),
  ];



  @override
  // this widget creates the back arrow when the search bar is clicked and shows locations
  Widget? buildLeading(BuildContext context) => IconButton(

      icon: const Icon(Icons.arrow_back),
      //close search bar and return nothing when pressed
      onPressed: () => close(context,null),
  );
    

  @override
  //this widget builds the locations page when user clicks the search bar
  Widget buildResults(BuildContext context) {
    //Finding exact match is case insensitive
    final match = allCampusLocations.where((location) =>
    location.toLowerCase() == query.toLowerCase()
    ).toList();

    if(match.isNotEmpty){
      // when user types location and presses 'Enter'
      return ListTile(
        //green circle pops up next to location map
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(match.first),
        subtitle: const Text('Tap to Navigate'),// located under location name

        onTap:(){
          //sending location back to map view
          onLocationSelected(match.first);
          close(context,match.first);
        },
      );
    }
    return Center(
      // if no match found
      child:Text(
        'No Location found for "$query"', // outputed center of screen
        style:const TextStyle(fontSize:18),
      ),
    );

  }

// this widget builds the suggested list that appears on screen as user types desired location
  @override
  Widget buildSuggestions(BuildContext context) {
    List<String> suggestions = allCampusLocations.where((location){
      //converted both result and input to lowercase
      final result = location.toLowerCase();
      final input = query.toLowerCase();
      return result.contains(input);
    }).toList();

    //supposed to allow me to scroll through list
    return ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index){
          final suggestion = suggestions[index];

          return ListTile(
            leading: const Icon(Icons.location_on), //locations pin icon
            title: Text(suggestion),
            onTap:(){
              //when user taps suggestion
              query = suggestion;
              onLocationSelected(suggestion);// send it to map view
              close(context,suggestion); // close search bar
            },
          );
        },
    );
  }
}
// actual search bar widget that appears on the map
//what users see
class CampusSearchBar extends StatelessWidget{
  //callback to send selected location to map view
  final Function(String)? onSelected;

  const CampusSearchBar({super.key,this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white, // white background for search
      elevation:4, // adds a shadow to make it stand out from map
      borderRadius: BorderRadius.circular(8), // rounded corners of search bar
      child: InkWell( // creates ripple shawdow effect on tap
        onTap: () {
          // when tapped open search interface
          showSearch(
            context: context,
            //passing in custom search delegate
            delegate: MySearchDelegate(
              //when search is selected
              onLocationSelected: (location) {
                //call back from map view to handle routing
                onSelected?.call(location);
              },
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical:22),
          child: const Row(
            children: [
              Icon(Icons.search, color: Colors.grey), // search icon
              SizedBox(width: 12), // space between icon and text
              Text(
                'Search campus locations ', // placeholder text
                style:TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


import 'building_info.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll2;

// Helper: create a list of 7 OperationHours (Mon-Sun) with separate weekday and weekend hours.
// Pass weekday open/close for Mon-Fri, and weekend open/close for Sat-Sun.
// Use hour 0, minute 0 for both open and close on a day to indicate closed (matches _closed convention).
List<OperationHours> _weeklyHours({
  required int weekdayOpen,
  required int weekdayClose,
  required int weekendOpen,
  required int weekendClose,
}) {
  final weekday = OperationHours(
    TimeOfDay(hour: weekdayOpen, minute: 0),
    TimeOfDay(hour: weekdayClose, minute: 0),
  );
  final weekend = OperationHours(
    TimeOfDay(hour: weekendOpen, minute: 0),
    TimeOfDay(hour: weekendClose, minute: 0),
  );
  return [
    weekday, // Monday
    weekday, // Tuesday
    weekday, // Wednesday
    weekday, // Thursday
    weekday, // Friday
    weekend, // Saturday
    weekend, // Sunday
  ];
}

// Helper: a closed-all-day entry (for days a building is not open).
OperationHours get _closed => OperationHours(
  TimeOfDay(hour: 0, minute: 0),
  TimeOfDay(hour: 0, minute: 0),
);

//using a map so switch case can just pick the right name(key) and then match up to the data(value) here
//TODO add destinations: University Apartments, Ridge, Wess Radio, secondary locations?
Map<String, BuildingInfo> buildingData = {
  //1st entry with example comments
  'Kemp Library': BuildingInfo( //name connects to actual object that holds the data
    name : "Kemp Library",
    description: "The main campus library. Features tutoring center, computer labs, printing, and more.",
    hours: [//each row is for a day Mon -> Sun
      OperationHours(TimeOfDay(hour: 7, minute: 30), TimeOfDay(hour: 23, minute: 0)),//Monday: 7:30am - 11:00pm
      OperationHours(TimeOfDay(hour: 7, minute: 30), TimeOfDay(hour: 23, minute: 0)),//Tuesday: 7:30am - 11:00pm
      OperationHours(TimeOfDay(hour: 7, minute: 30), TimeOfDay(hour: 23, minute: 0)),//Wednesday: 7:30am - 11:00pm
      OperationHours(TimeOfDay(hour: 7, minute: 30), TimeOfDay(hour: 23, minute: 0)),//Thursday: 7:30am - 11:00pm
      OperationHours(TimeOfDay(hour: 7, minute: 30), TimeOfDay(hour: 17, minute: 0)),//Friday: 7:30am - 5:00pm
      _closed,//Saturday: closed
      OperationHours(TimeOfDay(hour: 14, minute: 30), TimeOfDay(hour: 23, minute: 0)),//Sunday: 2:30pm - 11:00pm
    ],
    //what the building has to offer
    facilities: ['Study Rooms', 'Computer Lab', 'Tutoring Center', 'Printers'],
      //using image paths and converting them in mapview to be part of the gallery
    imagePaths: ['assets/images/building_photos/Kemp-Library-Front.jpg'],
    location: ll2.LatLng(40.99830,-75.17031)
  ),
// --- RESIDENCE HALLS (24-hour access) ---
  // NOTE: hours 0,0 -> 0,0 all week = 24/7 open convention

  'Laurel Residence Hall': BuildingInfo(
    name: 'Laurel Residence Hall',
    description: 'A traditional residence hall on campus housing ESU students. Features shared common areas and laundry facilities.',
    hours: _weeklyHours(weekdayOpen: 0, weekdayClose: 0, weekendOpen: 0, weekendClose: 0), // 24-hour resident access
    facilities: ['Laundry', 'Common Lounge', 'Vending Machines'],
    imagePaths: ['assets/images/building_photos/Laurel-Front.jpg'],
    location: ll2.LatLng(40.99605,-75.17303),
      tags: ['residence_hall']
  ),

  'Shawnee Residence Hall': BuildingInfo(
    name: 'Shawnee Residence Hall',
    description: 'A traditional residence hall providing on-campus housing for ESU students with shared common spaces.',
    hours: _weeklyHours(weekdayOpen: 0, weekdayClose: 0, weekendOpen: 0, weekendClose: 0), // 24-hour resident access
    facilities: ['Laundry', 'Common Lounge', 'Vending Machines'],
    imagePaths: ['assets/images/building_photos/Shawnee/Shawnee-Front.jpg'],
    location: ll2.LatLng(40.99598,-75.17213),
      tags: ['residence_hall']
  ),

  'Minsi Residence Hall': BuildingInfo(
    name: 'Minsi Residence Hall',
    description: 'A traditional residence hall offering on-campus living for ESU students.',
    hours: _weeklyHours(weekdayOpen: 0, weekdayClose: 0, weekendOpen: 0, weekendClose: 0), // 24-hour resident access
    facilities: ['Laundry', 'Common Lounge', 'Vending Machines'],
    imagePaths: ['assets/images/building_photos/Minsi/Minsi-Front.jpg'],
    location: ll2.LatLng(40.99547,-75.17210),
      tags: ['residence_hall']
  ),

  'Linden Residence Hall': BuildingInfo(
    name: 'Linden Residence Hall',
    description: 'A traditional residence hall offering on-campus living for ESU students.',
    hours: _weeklyHours(weekdayOpen: 0, weekdayClose: 0, weekendOpen: 0, weekendClose: 0), // 24-hour resident access
    facilities: ['Laundry', 'Common Lounge', 'Vending Machines'],
    imagePaths: ['assets/images/building_photos/Linden/Linden_Front.jpg'],
    location: ll2.LatLng(40.99605, -75.17105),
      tags: ['residence_hall']
  ),

  'Hemlock Suites': BuildingInfo(
    name: 'Hemlock Suites',
    description: 'A modern suite-style residence hall that also houses the University Police & Campus Information Center and the ESU Dining Services office.',
    hours: _weeklyHours(weekdayOpen: 0, weekdayClose: 0, weekendOpen: 0, weekendClose: 0), // 24-hour resident access
    facilities: ['Suite-Style Rooms', 'Laundry', 'Common Lounge', 'Geothermal Heating & Cooling'],
    imagePaths: ['assets/images/building_photos/Hemlock/Hemlock_Front.jpg',
      'assets/images/building_photos/Hemlock/Hemlock_Quad.jpg'],
    location: ll2.LatLng(40.99799,-75.17100),
      tags: ['residence_hall']
  ),

  'Lenape Residence Hall': BuildingInfo(
    name: 'Lenape Residence Hall',
    description: 'A traditional residence hall offering on-campus living for ESU students.',
    hours: _weeklyHours(weekdayOpen: 0, weekdayClose: 0, weekendOpen: 0, weekendClose: 0), // 24-hour resident access
    facilities: ['Laundry', 'Common Lounge', 'Vending Machines'],
    imagePaths: ['assets/images/building_photos/Lenape/Lenape-Front.jpg'],
    location: ll2.LatLng(40.99866,-75.17193),
      tags: ['residence_hall']
  ),

  'Hawthorn Suites': BuildingInfo(
    name: 'Hawthorn Suites',
    description: 'A modern suite-style residence hall with geothermal heating and cooling. Also houses the RecB Fitness Center in its lower level, open to all students.',
    hours: _weeklyHours(weekdayOpen: 0, weekdayClose: 0, weekendOpen: 0, weekendClose: 0), // 24-hour resident access
    facilities: ['Suite-Style Rooms', 'RecB Fitness Center', 'Laundry', 'Geothermal Heating & Cooling'],
    imagePaths: ['assets/images/building_photos/Hawthorn/Hawthorn_Inner.jpg'],
    location: ll2.LatLng(40.99908,-75.17233),
      tags: ['residence_hall']
  ),

  'Sycamore Suites': BuildingInfo(
    name: 'Sycamore Suites',
    description: 'A modern suite-style residence hall with geothermal heating and cooling. Houses student support services including Health & Wellness, Student Conduct, the Dean of Students, and the Title IX Coordinator.',
    hours: _weeklyHours(weekdayOpen: 0, weekdayClose: 0, weekendOpen: 0, weekendClose: 0), // 24-hour resident access
    facilities: ['Suite-Style Rooms', 'Laundry', 'Geothermal Heating & Cooling'],
    imagePaths: ['assets/images/building_photos/Sycamore/Sycamore_Quad.jpg'],
    location: ll2.LatLng(40.99721,-75.17246),
    tags: ['residence_hall']
  ),

  // --- DINING ---

  'Dansbury Commons': BuildingInfo(
    name: 'Dansbury Commons',
    description: 'ESU\'s all-you-care-to-eat main dining hall. Offers diverse stations including a grill, global kitchen, True Balance allergen-free options, bakery, and ice cream. Open to the public during the academic year.',
    hours: [
      OperationHours(TimeOfDay(hour: 7, minute: 0), TimeOfDay(hour: 20, minute: 0)),  // Monday: 7am - 8pm
      OperationHours(TimeOfDay(hour: 7, minute: 0), TimeOfDay(hour: 20, minute: 0)),  // Tuesday: 7am - 8pm
      OperationHours(TimeOfDay(hour: 7, minute: 0), TimeOfDay(hour: 20, minute: 0)),  // Wednesday: 7am - 8pm
      OperationHours(TimeOfDay(hour: 7, minute: 0), TimeOfDay(hour: 20, minute: 0)),  // Thursday: 7am - 8pm
      OperationHours(TimeOfDay(hour: 7, minute: 0), TimeOfDay(hour: 20, minute: 0)),  // Friday: 7am - 8pm
      OperationHours(TimeOfDay(hour: 10, minute: 0), TimeOfDay(hour: 19, minute: 0)), // Saturday: 10am - 7pm (with break)
      OperationHours(TimeOfDay(hour: 10, minute: 0), TimeOfDay(hour: 19, minute: 0)), // Sunday: 10am - 7pm (with break)
    ],
    facilities: ['All-You-Care-to-Eat Dining', 'Grill', 'Global Kitchen', 'Allergen-Free Station', 'Bakery', 'Ice Cream', 'P.O.D. Mini Market'],
    imagePaths: ['assets/images/building_photos/Dansbury/Dansbury-Interior.jpg'], //TODO take outdoor photo
    location: ll2.LatLng(40.99671,-75.17351)
  ),

  // --- ACADEMIC BUILDINGS ---

  'Monroe Hall': BuildingInfo(
    name: 'Monroe Hall',
    description: 'Renovated and reopened in 2012, Monroe Hall houses the Department of Communication Sciences & Disorders and the Department of Communication. Features laboratories, classrooms, offices, and a 68-seat screening room.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Classrooms', 'Communication Labs', 'Screening Room', 'Faculty Offices'],
    imagePaths: ['assets/images/building_photos/Monroe/Monroe-Hall-Front.jpg'],
    location: ll2.LatLng(40.99525,-75.17283)
  ),

  'Koehler Fieldhouse and Natatorium': BuildingInfo(
    name: 'Koehler Fieldhouse and Natatorium',
    description: 'The primary facility for academic programs in athletic training and exercise science. Home to intercollegiate athletics including basketball, volleyball, indoor track, wrestling, and swimming. Features a 2,000-seat arena and a heated swimming pool.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends (varies by event)
    facilities: ['2,000-Seat Arena', 'Swimming Pool / Natatorium', 'Wrestling Room', 'Teaching Gym', 'Locker Rooms'],
    imagePaths: ['assets/images/building_photos/Koehler/koehler-front-entrance.png',
      'assets/images/building_photos/Koehler/koehler-front.jpg',
      'assets/images/building_photos/Koehler/koehler-inside-court.png',
      'assets/images/building_photos/Koehler/koehler-inside-pool.jpg'],
    location: ll2.LatLng(40.99710,-75.16993)
  ),

  'Warren E. & Sandra Hoeffner Science and Technology Center': BuildingInfo(
    name: 'Warren E. & Sandra Hoeffner Science and Technology Center',
    description: 'Opened in 2008, this 120,000 sq ft building houses chemistry, math, computer science, and other science departments. Features a 200-seat auditorium, teaching and research labs, the McMunn Planetarium, and the Schisler Museum of Wildlife & Natural History.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Classrooms', 'Research Labs', 'Teaching Labs', '200-Seat Auditorium', 'McMunn Planetarium', 'Schisler Museum of Wildlife & Natural History', 'Rooftop Observatory'],
    imagePaths: ['assets/images/building_photos/SciTech/SciTech-Front.jpg'],
    location: ll2.LatLng(40.996636,-75.17557)
  ),

  'Moore Biology Hall': BuildingInfo(
    name: 'Moore Biology Hall',
    description: 'Houses biology programs and features a large group lecture hall, a greenhouse, and a wildlife museum.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Lecture Hall', 'Greenhouse', 'Wildlife Museum', 'Labs'],
    imagePaths: ['assets/images/building_photos/Moore/Moore-Front.jpg'],
    location: ll2.LatLng(40.99631,-75.17498)
  ),

  'Gessner Science Hall': BuildingInfo(
    name: 'Gessner Science Hall',
    description: 'Houses science laboratories and is home to ESU\'s Bloomberg Finance Lab, used for finance and business coursework.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Science Labs', 'Bloomberg Finance Lab', 'Classrooms'],
    imagePaths: ['assets/images/building_photos/Gessner/Gessner-Corner.jpg'],
    location: ll2.LatLng(40.9959637,-75.1748588)
  ),

  'Stroud Hall': BuildingInfo(
    name: 'Stroud Hall',
    description: 'The primary academic building on campus. This four-story building contains lecture halls, computer and language laboratories, instructional space, and faculty offices.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Lecture Halls', 'Computer Labs', 'Language Labs', 'Faculty Offices'],
    imagePaths: ['assets/images/building_photos/Stroud/Stroud-Front.jpg'],
    location: ll2.LatLng(40.99530,-75.17441)
  ),

  'DeNike Center for Human Services': BuildingInfo(
    name: 'DeNike Center for Human Services',
    description: 'Houses classrooms and laboratory areas for the departments of Health, Nursing, and Recreation & Leisure Services Management.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Classrooms', 'Health & Nursing Labs', 'Recreation Program Offices'],
    imagePaths: ['assets/images/building_photos/DeNike/DeNike-Front.jpg'],
    location: ll2.LatLng(40.99413,-75.17611)
  ),

  'Fine and Performing Arts Center': BuildingInfo(
    name: 'Fine and Performing Arts Center',
    description: 'A creative hub featuring two theaters, a gallery, a concert hall, rehearsal areas, and art studios. Also home to the ESU Stratasys Super Lab with a multi-color 3D printer.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends (varies by performance)
    facilities: ['Two Theaters', 'Concert Hall', 'Art Gallery', 'Art Studios', 'Rehearsal Spaces', '3D Printing Lab'],
    imagePaths: ['assets/images/building_photos/FineArts/Fine-Arts-Front.jpg',
      'assets/images/building_photos/FineArts/Fine-Arts-Theater.jpg'],
    location: ll2.LatLng(40.99855,-75.16642)
  ),

  'Zimbar-Liljenstein Hall': BuildingInfo(
    name: 'Zimbar-Liljenstein Hall',
    description: 'Houses academic programs for Physical Education/Health Education and Sport Management. Features a gymnasium and the Student Enrollment Center.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Gymnasium', 'Classrooms', 'Student Enrollment Center', 'Faculty Offices'],
    imagePaths: ['assets/images/building_photos/Zimbar/Zimbar-Front.png',
      'assets/images/building_photos/Zimbar/Zimbar-Court.jpg'],
    location: ll2.LatLng(40.99413,-75.17380)
  ),

  // --- ATHLETICS / OUTDOOR ---

  'Eiler-Martin Stadium': BuildingInfo(
    name: 'Eiler-Martin Stadium',
    description: 'ESU\'s outdoor stadium used for football, soccer, and other athletic events. Home to the Warriors on the field.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends (open during events)
    facilities: ['Football/Soccer Field', 'Bleacher Seating', 'Press Box'],
    imagePaths: ['assets/images/building_photos/EilerMartin/EilerMartin.jpg'],
    location: ll2.LatLng(40.9940069,-75.1728448)
  ),

  'Dave Carllyon Pavilion': BuildingInfo(
    name: 'Dave Carllyon Pavilion',
    description: 'An outdoor pavilion on the ESU campus used for athletic and recreational activities.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Outdoor Space', 'Seating Area'],
    imagePaths: ['assets/images/building_photos/DaveCarllyon/DaveC.jpg'],
    location: ll2.LatLng(40.9985246,-75.1728687)
  ),

  // --- RECREATION ---

  'Mattioli Recreation Center': BuildingInfo(
    name: 'Mattioli Recreation Center',
    description: 'ESU\'s main recreation and fitness center, serving approximately 1,500 students daily. Recently renovated for 2025-26 with new flooring and ESU branding. Features cardio and weight equipment, basketball courts, an elevated running track, racquetball courts, an aerobics room, and an Esports room.',
    hours: [
      OperationHours(TimeOfDay(hour: 6, minute: 0), TimeOfDay(hour: 23, minute: 0)),//Monday: 6:00am - 11:00pm
      OperationHours(TimeOfDay(hour: 6, minute: 0), TimeOfDay(hour: 23, minute: 0)),//Tuesday: 6:00am - 11:00pm
      OperationHours(TimeOfDay(hour: 6, minute: 0), TimeOfDay(hour: 23, minute: 0)),//Wednesday: 6:00am - 11:00pm
      OperationHours(TimeOfDay(hour: 6, minute: 0), TimeOfDay(hour: 23, minute: 0)),//Thursday: 6:00am - 11:00pm
      OperationHours(TimeOfDay(hour: 6, minute: 0), TimeOfDay(hour: 21, minute: 0)),//Friday: 6:00am - 9:00pm
      OperationHours(TimeOfDay(hour: 11, minute: 0), TimeOfDay(hour: 21, minute: 0)),//Saturday: 11:00am - 9:00pm
      OperationHours(TimeOfDay(hour: 11, minute: 0), TimeOfDay(hour: 21, minute: 0)),//Sunday: 11:00am - 9:00pm
    ],
    facilities: ['Cardio Equipment', 'Weight Room', 'Basketball Courts', 'Volleyball Courts', 'Pickleball Courts', 'Indoor Soccer', 'Elevated Running Track', 'Racquetball Courts', 'Aerobics Room', 'Esports Room', 'Group Fitness Classes'],
    imagePaths: ['assets/images/building_photos/Mattioli/Mattioli-Front.jpg',
      'assets/images/building_photos/Mattioli/Mattioli-Courts.jpg',
      'assets/images/building_photos/Mattioli/Mattioli-Group-Fit.jpg',
      'assets/images/building_photos/Mattioli/Mattioli-Gym-Weights.jpg',
      'assets/images/building_photos/Mattioli/Mattioli-Gym-Cardio.jpg'],
    location: ll2.LatLng(40.99546,-75.17034)
  ),

  // --- ACADEMIC / LECTURE ---

  'Joseph H. & Mildred E. Beers Lecture Hall': BuildingInfo(
    name: 'Joseph H. & Mildred E. Beers Lecture Hall',
    description: 'A 140-seat lecture hall that also serves as a distance learning facility, equipped for hybrid and remote instruction.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['140-Seat Lecture Hall', 'Distance Learning Technology', 'AV Equipment'],
    imagePaths: ['assets/images/building_photos/Beers/Beers-Front.png',
      'assets/images/building_photos/Beers/Beers-Inside.jpg'],
    location: ll2.LatLng(40.9954604,-75.1750394)
  ),

  // --- ADMINISTRATION ---

  'Reibman Administration Building': BuildingInfo(
    name: 'Reibman Administration Building',
    description: 'ESU\'s main administration building and the first building visitors see upon arriving on Normal Street. Houses the Office of Admissions and other administrative offices.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends (admin M-F)
    facilities: ['Office of Admissions', 'Administrative Offices'],
    imagePaths: ['assets/images/building_photos/Reibman/Reibman-Front.jpg'],
    location: ll2.LatLng(40.99564,-75.17683)
  ),

  'Conference Services & Multicultural House': BuildingInfo(
    name: 'Conference Services & Multicultural House',
    description: 'Houses ESU\'s Conference Services department as well as the Multicultural Center, which supports diversity and inclusion programming on campus.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Conference Rooms', 'Event Space'],
    imagePaths: ['assets/images/building_photos/MulticulturalHouse/MulticulturalHouse-Front.jpg'],
    location: ll2.LatLng(40.99587,-75.17637)
  ),

  // --- PERFORMING ARTS ---

  'Abeloff Center for the Performing Arts': BuildingInfo(
    name: 'Abeloff Center for the Performing Arts',
    description: 'A performing arts venue on campus that hosts concerts, theater productions, and community events.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends (open during scheduled performances/events)
    facilities: ['Performance Hall', 'Stage', 'Seating'],
    imagePaths: ['assets/images/building_photos/Abeloff/Abeloff-Front.png',
      'assets/images/building_photos/Abeloff/Abeloff-Inside.jpg'],
    location: ll2.LatLng(40.99453,-75.17533)
  ),

  // --- ACADEMIC ---

  'Rosenkrans Hall': BuildingInfo(
    name: 'Rosenkrans Hall',
    description: 'Houses offices, classrooms, and labs for Digital Media Technologies. Also home to the University-Wide Tutorial Program, which provides academic support to all students.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Digital Media Labs', 'Classrooms', 'University-Wide Tutorial Program', 'Faculty Offices'],
    imagePaths: ['assets/images/building_photos/Rosenkrans/Rosenkrans-Front.jpg'],
    location: ll2.LatLng(40.99494,-75.17467)
  ),

  // --- STUDENT CENTER ---

  'University Center': BuildingInfo(
    name: 'University Center',
    description: 'The hub of student life at ESU. Features a food court (Center Court), a commuter lounge, a computer lab/lounge, meeting space for the Student Government Association, the Student Activity Association offices, and the ESU Barnes & Noble Bookstore.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends (varies by vendor)
    facilities: ['Food Court (Center Court)', 'Barnes & Noble Bookstore', 'Commuter Lounge', 'Computer Lab/Lounge', 'Student Government Association Office', 'Student Activity Association Office'],
      imagePaths: ['assets/images/building_photos/UniversityCenter_New/UniversityCenter-Concept.jpg',
        'assets/images/building_photos/UniversityCenter_New/UniversityCenter_Entrance.jpg'],
    location: ll2.LatLng(40.995650,-75.173331)
  ),

  // --- ALUMNI ---

  'Henry A. Ahnert Jr. Alumni Center': BuildingInfo(
    name: 'Henry A. Ahnert Jr. Alumni Center',
    description: 'Home to ESU\'s alumni relations programs and events. Serves as a gathering space for alumni engagement and university development activities.',
    hours: _weeklyHours(weekdayOpen: 7, weekdayClose: 18, weekendOpen: 0, weekendClose: 0), // 7am - 6pm weekdays, closed weekends
    facilities: ['Meeting Rooms', 'Event Space', 'Alumni Relations Office'],
    imagePaths: ['assets/images/building_photos/AlumniCenter/AlumniCenter-Front.jpg'],
    location: ll2.LatLng(40.9996531,-75.1713405)
  ),
};
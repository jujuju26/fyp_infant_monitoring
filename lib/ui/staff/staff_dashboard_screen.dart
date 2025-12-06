import 'package:flutter/material.dart';
import 'meal_screen.dart'; // Placeholder for meal screen
import 'staff_booking_screen.dart'; // Placeholder for booking screen
import 'staff_profile_screen.dart'; // Staff Profile screen
import 'staff_home_screen.dart'; // Placeholder for staff home screen
import 'staff_report_screen.dart'; // Placeholder for report screen

class StaffDashboardScreen extends StatefulWidget {
  final int selectedIndex;

  const StaffDashboardScreen({super.key, this.selectedIndex = 0}); // default to Home

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  late int _selectedIndex;

  final List<Widget> _pages = [
    StaffHomeScreen(),
    StaffBookingsScreen(),
    MealScreen(),
    StaffReportScreen(),
    StaffProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex; // initialize from constructor
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC2868B);

    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontFamily: 'Poppins'),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins'),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online_rounded), label: 'Booking'),
          BottomNavigationBarItem(icon: Icon(Icons.fastfood_rounded), label: 'Meal'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment_rounded), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

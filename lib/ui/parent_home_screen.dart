import 'package:flutter/material.dart';
import 'infant_monitoring/infant_monitoring_home.dart';
import 'notification_screen.dart';
import 'parent_profile_screen.dart';
import 'report_screen.dart';
import 'confinement_package_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    InfantMonitoringHome(),
    NotificationScreen(),
    ReportScreen(),
    ConfinementPackageScreen(),
    ParentProfileScreen(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC2868B);

    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: accent,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontFamily: 'Poppins'),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins'),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Notifications'),
            BottomNavigationBarItem(icon: Icon(Icons.assessment_rounded), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Package'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}


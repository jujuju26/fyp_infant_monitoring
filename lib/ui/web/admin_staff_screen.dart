import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_dashboard_screen.dart';
import 'admin_logout_screen.dart';
import 'admin_packages_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_report_screen.dart';

class AdminStaffScreen extends StatefulWidget {
  @override
  _AdminStaffScreenState createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String adminName = "";
  String adminRole = "";

  TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String sortType = "A-Z";

  List<Map<String, dynamic>> staffList = [];

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _fetchStaff();
  }

  Future<void> _loadAdminInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await _firestore.collection('admin').doc(uid).get();

      if (doc.exists) {
        setState(() {
          adminName = doc.data()?['name'] ?? "";
          adminRole = doc.data()?['role'] ?? "Admin";
        });
      }
    } catch (e) {
      debugPrint("Admin load error: $e");
    }
  }

  Future<void> _fetchStaff() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('staff').get();

      staffList = snapshot.docs.map((doc) {
        final storedPath = (doc['profileImageUrl'] ?? "").toString().trim();

        return {
          'id': doc.id,
          'name': (doc['username'] ?? '').toString().trim(),
          'email': (doc['email'] ?? '').toString().trim(),
          'role': (doc['role'] ?? 'Staff').toString(),
          'profilePath': storedPath,
        };
      }).toList();

      _sortStaff();
      setState(() {});
    } catch (e) {
      print("Error fetching staff: $e");
    }
  }

  void _sortStaff() {
    if (sortType == "A-Z") {
      staffList.sort((a, b) => a['name'].compareTo(b['name']));
    } else {
      staffList.sort((a, b) => b['name'].compareTo(a['name']));
    }
  }

  Future<String?> _getValidImageUrl(String path) async {
    if (path.isEmpty) return null;

    try {
      final ref = FirebaseStorage.instance.ref(path);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Image fetch failed → $e");
      return null;
    }
  }

  Future<void> _deleteStaff(String staffId) async {
    try {
      await _firestore.collection('staff').doc(staffId).delete();

      setState(() {
        staffList.removeWhere((s) => s['id'] == staffId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff member deleted successfully!')),
      );
    } catch (e) {
      print("Delete error: $e");
    }
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Image.asset('assets/images/logo2.png', height: 60),
          const SizedBox(height: 40),

          _sideTile(Icons.dashboard, "Dashboard", false),
          _sideTile(Icons.people, "Staff", true),
          _sideTile(Icons.shopping_bag_outlined, "Packages", false),
          _sideTile(Icons.insert_chart, "Report", false),

          const Spacer(),
          Divider(color: Colors.grey[300]),
          ListTile(
            leading: const Icon(
                Icons.power_settings_new, color: Colors.black54),
            title: const Text("Logout"),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sideTile(IconData icon, String label, bool selected) {
    return ListTile(
      leading: Icon(icon,
          color: selected ? Colors.red.shade200 : Colors.black54),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: "Poppins",
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? Colors.red.shade200 : Colors.black87,
        ),
      ),
      onTap: () => _navigateTo(label),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFFADADD),
            child: const Icon(Icons.person,
                size: 24, color: Color(0xFFC2868B)),
          ),
          const SizedBox(width: 10),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(adminName,
                  style: const TextStyle(fontSize: 14, fontFamily: "Poppins")),
              Text(adminRole,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),

          PopupMenuButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            itemBuilder: (_) =>
            const [
              PopupMenuItem(value: "profile", child: Text("Profile")),
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
            onSelected: (value) {
              if (value == "profile") {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AdminProfileScreen()));
              } else if (value == "logout") {
                _logout();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Map staff) {
    final String name = staff['name'];
    final String email = staff['email'];
    final String role = staff['role'];
    final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "?";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFADADD)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // initials avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFFADADD),
              child: Text(
                firstLetter,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC2868B),
                  fontFamily: "Poppins",
                ),
              ),
            ),

            const SizedBox(height: 12),

            // name
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: "Poppins",
                color: Color(0xFFC2868B),
              ),
            ),

            const SizedBox(height: 3),

            // role
            Text(
              role,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontFamily: "Poppins",
              ),
            ),

            const SizedBox(height: 3),

            // email
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontFamily: "Poppins",
              ),
            ),

            const Spacer(),

            // delete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                label: const Text("Delete"),
                onPressed: () => _deleteStaff(staff['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC2868B),
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(String label) {
    switch (label) {
      case "Dashboard":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => AdminDashboardScreen()));
        break;
      case "Staff":
        Navigator.push(context,
          MaterialPageRoute(builder: (context) => AdminStaffScreen()),
        );
        break;
      case 'Packages':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminPackagesScreen()),
        );
        break;
      case "Report":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => AdminReportScreen()));
        break;
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AdminLogoutScreen()),
            (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    List<Map> filteredStaff = staffList.where((s) {
      final name = s['name'].toLowerCase();
      final email = s['email'].toLowerCase();
      return name.contains(searchQuery) || email.contains(searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),
      body: Row(
        children: [
          _buildSidebar(),

          Expanded(
            child: Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Staff",
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade200)),

                            DropdownButton<String>(
                              value: sortType,
                              items: const [
                                DropdownMenuItem(
                                    value: "A-Z", child: Text("A–Z")),
                                DropdownMenuItem(
                                    value: "Z-A", child: Text("Z–A")),
                              ],
                              onChanged: (val) {
                                sortType = val!;
                                _sortStaff();
                                setState(() {});
                              },
                            ),
                          ],
                        ),

                        SizedBox(height: 20),

                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) =>
                                setState(() => searchQuery = v.toLowerCase()),
                            decoration: InputDecoration(
                              icon: Icon(Icons.search),
                              hintText: "Search staff...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),

                        SizedBox(height: 20),

                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 0.80,
                            ),
                            itemCount: filteredStaff.length,
                            itemBuilder: (_, i) =>
                                _buildStaffCard(filteredStaff[i]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

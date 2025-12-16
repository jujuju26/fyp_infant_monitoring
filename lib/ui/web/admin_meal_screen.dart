import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'admin_inventory_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_packages_screen.dart';
import 'admin_report_screen.dart';
import 'admin_logout_screen.dart';
import 'admin_profile_screen.dart';

class AdminMealScreen extends StatefulWidget {
  const AdminMealScreen({Key? key}) : super(key: key);

  @override
  State<AdminMealScreen> createState() => _AdminMealScreenState();
}

class _AdminMealScreenState extends State<AdminMealScreen>
    with SingleTickerProviderStateMixin {
  final accent = const Color(0xFFC2868B);
  final lightPink = const Color(0xFFFADADD);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Admin info variables
  String adminName = "";
  String adminRole = "Admin";

  // Meal option data
  String mealDocId = "";
  Map<String, dynamic> mealData = {
    "breakfast": [],
    "lunch": [],
    "dinner": [],
  };

  late TabController _tabController;

  final categories = ["Breakfast", "Lunch", "Dinner"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminInfo();
    _loadMeals();
  }

  // ============================================================
  // LOAD ADMIN INFO
  // ============================================================
  Future<void> _loadAdminInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final doc =
      await FirebaseFirestore.instance.collection('admin').doc(uid).get();

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

  // ============================================================
  // LOGOUT FUNCTION
  // ============================================================
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminLogoutScreen()),
            (route) => false,
      );
    } catch (e) {
      print("Logout error: $e");
    }
  }

  // ============================================================
  // LOAD MEALS FROM FIRESTORE
  // ============================================================
  Future<void> _loadMeals() async {
    final snapshot = await _firestore.collection("meal_options").get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        mealDocId = snapshot.docs.first.id;
        mealData = snapshot.docs.first.data();
      });
    }
  }

  // ============================================================
  // CRUD FUNCTIONS
  // ============================================================
  Future<void> _addMealItem(String category) async {
    TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Add $category Item"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter meal name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;

              final updatedList = List<String>.from(mealData[category.toLowerCase()]);
              updatedList.add(value);

              await _firestore.collection("meal_options").doc(mealDocId).update({
                category.toLowerCase(): updatedList
              });

              setState(() => mealData[category.toLowerCase()] = updatedList);
              Navigator.pop(context);
            },
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _editMealItem(String category, int index) async {
    TextEditingController controller =
    TextEditingController(text: mealData[category.toLowerCase()][index]);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Edit $category Item"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isEmpty) return;

              final updatedList = List<String>.from(mealData[category.toLowerCase()]);
              updatedList[index] = newValue;

              await _firestore.collection("meal_options").doc(mealDocId).update({
                category.toLowerCase(): updatedList
              });

              setState(() => mealData[category.toLowerCase()] = updatedList);
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMealItem(String category, int index) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Item"),
        content: const Text("Are you sure you want to delete this meal?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final updatedList = List<String>.from(mealData[category.toLowerCase()]);
              updatedList.removeAt(index);

              await _firestore.collection("meal_options").doc(mealDocId).update({
                category.toLowerCase(): updatedList
              });

              setState(() => mealData[category.toLowerCase()] = updatedList);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================
  Widget _buildSidebar() {
    List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.people, 'label': 'Staff'},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Packages'},
      {'icon': Icons.set_meal_outlined, 'label': 'Meal'},
      {'icon': Icons.inventory_2_outlined, 'label': 'Inventory', 'selected': false},
      {'icon': Icons.insert_chart, 'label': 'Report'},
    ];

    return Container(
      width: 240,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Image.asset('assets/images/logo2.png', height: 60),
          ),

          Expanded(
            child: ListView(
              children: items.map((item) {
                bool selected = item['label'] == "Meal";
                return ListTile(
                  leading: Icon(
                    item['icon'],
                    color: selected ? Colors.red.shade200 : Colors.black54,
                  ),
                  title: Text(
                    item['label'],
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      color: selected ? Colors.red.shade200 : Colors.black87,
                    ),
                  ),
                  onTap: () => _navigateTo(item['label']),
                );
              }).toList(),
            ),
          ),
          Divider(color: Colors.grey[300]),
          ListTile(
            leading: const Icon(Icons.power_settings_new, color: Colors.black54),
            title: const Text('Logout', style: TextStyle(fontFamily: 'Poppins')),
            onTap: _logout,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _navigateTo(String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
        break;
      case 'Staff':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => AdminStaffScreen()));
        break;
      case 'Packages':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminPackagesScreen()));
        break;
      case 'Meal':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminMealScreen()));
        break;
      case 'Inventory':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminInventoryScreen()));
        break;
      case 'Report':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminReportScreen()));
        break;
    }
  }

  // ============================================================
  // TOP BAR (same as Dashboard)
  // ============================================================
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
            child: const Icon(Icons.person, color: Color(0xFFC2868B)),
          ),
          const SizedBox(width: 10),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                adminName.isEmpty ? "Loading..." : adminName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                adminRole,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          PopupMenuButton<String>(
            icon: const Icon(Icons.keyboard_arrow_down),
            onSelected: (value) {
              if (value == "profile") {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                );
              } else if (value == "logout") {
                _logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "profile", child: Text("Profile")),
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MEAL LIST BUILDER
  // ============================================================
  Widget _buildMealList(String category) {
    final items = mealData[category.toLowerCase()] ?? [];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                blurRadius: 4,
                offset: const Offset(0, 2),
                color: Colors.black.withOpacity(0.05),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  items[index],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueGrey),
                onPressed: () => _editMealItem(category, index),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _deleteMealItem(category, index),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // MAIN UI LAYOUT
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          final category = categories[_tabController.index];
          _addMealItem(category);
        },
      ),
      body: Row(
        children: [
          _buildSidebar(),

          Expanded(
            child: Column(
              children: [
                _buildTopBar(),

                // Tab bar
                Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Meal List Title
                      Text(
                        'Meal List',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade200,
                          fontFamily: 'Poppins',
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tabs
                      TabBar(
                        controller: _tabController,
                        labelColor: accent,
                        unselectedLabelColor: Colors.black54,
                        indicatorColor: accent,
                        tabs: const [
                          Tab(text: "Breakfast"),
                          Tab(text: "Lunch"),
                          Tab(text: "Dinner"),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMealList("breakfast"),
                      _buildMealList("lunch"),
                      _buildMealList("dinner"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

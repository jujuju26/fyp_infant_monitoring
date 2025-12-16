import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import 'admin_logout_screen.dart';
import 'admin_meal_screen.dart';
import 'admin_packages_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_report_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_bookings_screen.dart';

class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  static const accent = Color(0xFFC2868B);
  static const lightPink = Color(0xFFFADADD);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> items = [];

  String adminName = "";
  String adminRole = "";

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _loadInventory();
  }

  // ================= ADMIN INFO =================
  Future<void> _loadAdminInfo() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _firestore.collection('admin').doc(uid).get();
    if (doc.exists) {
      adminName = doc['name'] ?? "";
      adminRole = doc['role'] ?? "Admin";
      setState(() {});
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLogoutScreen()),
          (route) => false,
    );
  }

  // ================= LOAD INVENTORY =================
  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);

    final snap = await _firestore.collection("inventory").get();
    items = snap.docs.map((doc) {
      final d = doc.data();
      return {
        "id": doc.id,
        "name": d["name"] ?? "",
        "category": d["category"] ?? "",
        "quantity": d["currentQty"] ?? 0, // ✅ FIX
        "threshold": d["minQty"] ?? 0, // ✅ FIX
      };
    }).toList();

    setState(() => _isLoading = false);
  }

  // ================= ADD NEW STOCK =================
  Future<void> _addItemDialog() async {
    final idController = TextEditingController();
    final nameController = TextEditingController();

    int currentQty = 0;
    int minQty = 0;

    String selectedCategory = "Diapers";
    String selectedUnit = "pcs";

    final Map<String, String> categoryUnitMap = {
      "Diapers": "pcs",
      "Milk": "ml",
      "Clothes": "pcs",
      "Toiletries": "ml",
      "Others": "pcs",
    };

    final List<String> categories = categoryUnitMap.keys.toList();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Inventory Item"),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Item ID
                    _input(idController, "Item ID (e.g. diapers)"),

                    // Item Name
                    _input(nameController, "Item Name"),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: "Category"),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ),
                      )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategory = value!;
                          selectedUnit = categoryUnitMap[value]!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Unit (AUTO, READ-ONLY)
                    TextFormField(
                      readOnly: true,
                      decoration: const InputDecoration(labelText: "Unit"),
                      controller: TextEditingController(text: selectedUnit),
                    ),
                    const SizedBox(height: 20),

                    // Initial Quantity (STEPPER)
                    _quantityStepper(
                      label: "Initial Quantity ($selectedUnit)",
                      value: currentQty,
                      onChanged: (v) => setDialogState(() => currentQty = v),
                    ),

                    // Minimum Quantity (STEPPER)
                    _quantityStepper(
                      label: "Minimum Quantity ($selectedUnit)",
                      value: minQty,
                      onChanged: (v) => setDialogState(() => minQty = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                child: const Text("Add", style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  final id = idController.text.trim().toLowerCase();
                  if (id.isEmpty || nameController.text.trim().isEmpty) return;

                  final ref = _firestore.collection("inventory").doc(id);
                  if ((await ref.get()).exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Item already exists")),
                    );
                    return;
                  }

                  await ref.set({
                    "name": nameController.text.trim(),
                    "category": selectedCategory,
                    "unit": selectedUnit,
                    "currentQty": currentQty,
                    "minQty": minQty,
                    "updatedBy": adminName,
                    "updatedAt": FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _loadInventory();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= UPDATE STOCK =================
  Future<void> _updateStock(String id, int currentQty, bool isRestock) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: Text(isRestock ? "Restock Item" : "Deduct Item"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Quantity"),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                child: const Text(
                    "Confirm", style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  final input = int.tryParse(controller.text) ?? 0;
                  final newQty = isRestock ? currentQty + input : currentQty -
                      input;

                  await _firestore.collection("inventory").doc(id).update({
                    "currentQty": newQty < 0 ? 0 : newQty,
                    "updatedAt": FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _loadInventory();
                },
              ),
            ],
          ),
    );
  }

  Future<void> _deleteItem(String id) async {
    await _firestore.collection("inventory").doc(id).delete();
    _loadInventory();
  }

  Widget _input(TextEditingController c, String label, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _quantityStepper({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    final controller = TextEditingController(text: value.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins')),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
              ),

              // DIRECT NUMBER INPUT
              SizedBox(
                width: 90,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null && parsed >= 0) {
                      onChanged(parsed);
                    }
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Inventory Management',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red.shade200,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: accent),
                                icon: const Icon(
                                    Icons.add, color: Colors.white),
                                label: const Text("Add Stock",
                                    style: TextStyle(color: Colors.white)),
                                onPressed: _addItemDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildInventoryTable(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= TABLE =================
  Widget _buildInventoryTable() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _HeaderCell("Item", flex: 3),
              _HeaderCell("Category", flex: 2),
              _HeaderCell("Quantity", flex: 2),
              _HeaderCell("Threshold", flex: 2),
              _HeaderCell("Actions", flex: 3),
            ],
          ),
          const Divider(),
          ...items.map((item) {
            final q = item["quantity"];
            final t = item["threshold"];
            final isLow = q <= t;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Text(item["name"]),
                          if (isLow)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text("LOW STOCK",
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.red)),
                            ),
                        ],
                      ),
                    ),
                    _RowCell(item["category"], flex: 2),
                    _RowCell("$q", flex: 2, color: isLow ? Colors.red : null),
                    _RowCell("$t", flex: 2),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: accent),
                            onPressed: () => _updateStock(item["id"], q, true),
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.remove_circle, color: Colors.orange),
                            onPressed: () => _updateStock(item["id"], q, false),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteItem(item["id"]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // TOP BAR (UNCHANGED)
  // ------------------------------------------------------
  Widget _buildTopBar() {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: lightPink,
            child: const Icon(Icons.person, size: 24, color: accent),
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
                adminRole.isEmpty ? "Admin" : adminRole,
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
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminProfileScreen()));
              } else if (value == "logout") {
                Navigator.pushReplacement(context, MaterialPageRoute(
                    builder: (_) => const AdminLogoutScreen()));
              }
            },
            itemBuilder: (context) =>
            const [
              PopupMenuItem(value: "profile", child: Text("Profile")),
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // SIDEBAR (UNCHANGED)
  // ------------------------------------------------------
  Widget _buildSidebar() {
    List<Map<String, dynamic>> sidebarItems = [
      {'icon': Icons.dashboard, 'label': 'Dashboard', 'selected': false},
      {'icon': Icons.people, 'label': 'Staff', 'selected': false},
      {
        'icon': Icons.shopping_bag_outlined,
        'label': 'Packages',
        'selected': false
      },
      {'icon': Icons.set_meal_outlined, 'label': 'Meal', 'selected': false},
      {
        'icon': Icons.inventory_2_outlined,
        'label': 'Inventory',
        'selected': true
      },
      {'icon': Icons.book_online, 'label': 'Bookings', 'selected': false},
      {'icon': Icons.insert_chart, 'label': 'Report', 'selected': false},
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
            child: ListView.builder(
              itemCount: sidebarItems.length,
              itemBuilder: (context, index) {
                final item = sidebarItems[index];
                return ListTile(
                  leading: Icon(item['icon'],
                      color: item['selected'] ? Colors.red.shade200 : Colors
                          .black54),
                  title: Text(item['label'],
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: item['selected']
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: item['selected'] ? Colors.red.shade200 : Colors
                            .black87,
                      )),
                  onTap: () => _navigateTo(item['label']),
                );
              },
            ),
          ),
          Divider(color: Colors.grey[300]),
          ListTile(
            leading: const Icon(
              Icons.power_settings_new,
              color: Colors.black54,
            ),
            title: const Text(
              'Logout',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
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
      case 'Bookings':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminBookingsScreen()));
        break;
      case 'Report':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminReportScreen()));
        break;
    }
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  const _HeaderCell(this.label, {this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _RowCell extends StatelessWidget {
  final String text;
  final int flex;
  final Color? color;
  const _RowCell(this.text, {this.flex = 1, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: color ?? Colors.black87)),
    );
  }
}

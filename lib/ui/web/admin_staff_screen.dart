import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'admin_meal_screen.dart';
import 'admin_packages_screen.dart';
import 'admin_report_screen.dart';
import 'admin_logout_screen.dart';
import 'admin_profile_screen.dart';

class AdminStaffScreen extends StatefulWidget {
  @override
  _AdminStaffScreenState createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const accent = Color(0xFFC2868B);
  static const lightPink = Color(0xFFFADADD);

  // Admin info
  String adminName = "";
  String adminRole = "Admin";

  // Search + sorting
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
      final doc = await _firestore.collection("admin").doc(uid).get();

      if (doc.exists) {
        setState(() {
          adminName = doc.data()?["name"] ?? "";
          adminRole = doc.data()?["role"] ?? "Admin";
        });
      }
    } catch (e) {
      debugPrint("Admin Load Error: $e");
    }
  }

  Future<void> _fetchStaff() async {
    final snap = await _firestore.collection("staff").get();

    setState(() {
      staffList = snap.docs.map((d) {
        return {
          "id": d.id,
          ...d.data(),
        };
      }).toList();
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLogoutScreen()),
          (route) => false,
    );
  }

  Future<Map<String, String>> _loadParentNames(
      List<QueryDocumentSnapshot> infants) async {
    Map<String, String> result = {};

    for (var doc in infants) {
      final data = doc.data() as Map<String, dynamic>;
      final parentId = data["parentId"];

      if (parentId != null && !result.containsKey(parentId)) {
        final parentDoc =
        await _firestore.collection("parent").doc(parentId).get();

        final parentData = parentDoc.data();
        final name = parentData?["name"] ?? parentData?["email"] ?? "Parent";

        result[parentId] = name;
      }
    }

    return result;
  }

  Widget _buildSidebar() {
    List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.people, 'label': 'Staff'},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Packages'},
      {'icon': Icons.set_meal_outlined, 'label': 'Meal'},
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
            child: Image.asset("assets/images/logo2.png", height: 60),
          ),
          Expanded(
            child: ListView(
              children: items.map((item) {
                bool selected = item['label'] == "Staff";
                return ListTile(
                  leading: Icon(
                    item['icon'],
                    color: selected ? Colors.red.shade200 : Colors.black54,
                  ),
                  title: Text(
                    item['label'],
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
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
            title:
            const Text("Logout", style: TextStyle(fontFamily: "Poppins")),
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
        break;
      case 'Packages':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminPackagesScreen()));
        break;
      case 'Meal':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AdminMealScreen()));
        break;
      case 'Report':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminReportScreen()));
        break;
    }
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
            backgroundColor: lightPink,
            child: const Icon(Icons.person, color: accent),
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
                    fontFamily: "Poppins"),
              ),
              Text(
                adminRole,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontFamily: "Poppins"),
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
                    MaterialPageRoute(
                        builder: (_) => const AdminProfileScreen()));
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

  void _openAssignInfantDialog(String staffId, String staffName) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String? selectedParentId;
        String? selectedInfantId;

        return StatefulBuilder(builder: (dialogCtx, setStateDialog) {
          return AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text("Assign Infant to $staffName",
                style: const TextStyle(
                    fontFamily: "Poppins", fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Parent dropdown
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection("parent").snapshots(),
                    builder: (ctx, snapParents) {
                      if (!snapParents.hasData)
                        return const LinearProgressIndicator();

                      final parents = snapParents.data!.docs;

                      return DropdownButtonFormField<String>(
                        value: selectedParentId,
                        decoration: const InputDecoration(
                          labelText: "Select Parent",
                          border: OutlineInputBorder(),
                        ),
                        items: parents.map((p) {
                          final data = p.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                                data["name"] ??
                                    data["email"] ??
                                    "Parent",
                                style:
                                const TextStyle(fontFamily: "Poppins")),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedParentId = val;
                            selectedInfantId = null;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Infant dropdown
                  if (selectedParentId != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection("parent")
                          .doc(selectedParentId)
                          .collection("infants")
                          .snapshots(),
                      builder: (ctx, snapInfants) {
                        if (!snapInfants.hasData)
                          return const LinearProgressIndicator();

                        final infants = snapInfants.data!.docs;

                        return DropdownButtonFormField<String>(
                          value: selectedInfantId,
                          decoration: const InputDecoration(
                            labelText: "Select Infant",
                            border: OutlineInputBorder(),
                          ),
                          items: infants.map((inf) {
                            final d = inf.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: inf.id,
                              child: Text(d["name"] ?? "Infant",
                                  style: const TextStyle(fontFamily: "Poppins")),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setStateDialog(() => selectedInfantId = val),
                        );
                      },
                    )
                  else
                    const Text("Select parent first",
                        style: TextStyle(
                            fontFamily: "Poppins", color: Colors.black54)),
                ],
              ),
            ),
            actions: [
              TextButton(
                child:
                const Text("Cancel", style: TextStyle(fontFamily: "Poppins")),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                onPressed:
                selectedParentId == null || selectedInfantId == null
                    ? null
                    : () async {
                  await _assignInfantToStaff(
                    staffId: staffId,
                    parentId: selectedParentId!,
                    parentInfantId: selectedInfantId!,
                  );
                  Navigator.pop(dialogCtx);
                },
                child: const Text("Assign",
                    style: TextStyle(color: Colors.white, fontFamily: "Poppins")),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _assignInfantToStaff({
    required String staffId,
    required String parentId,
    required String parentInfantId,
  }) async {
    final parentInfantRef = _firestore
        .collection("parent")
        .doc(parentId)
        .collection("infants")
        .doc(parentInfantId);

    final doc = await parentInfantRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;

    final staffInfantRef = _firestore
        .collection("staff")
        .doc(staffId)
        .collection("infants")
        .doc(parentInfantId);

    if ((await staffInfantRef.get()).exists) {
      return;
    }

    await staffInfantRef.set({
      ...data,
      "parentId": parentId,
      "assignedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _removeAssignment(
      String staffId, String infantId, String name) async {
    await _firestore
        .collection("staff")
        .doc(staffId)
        .collection("infants")
        .doc(infantId)
        .delete();
  }

  Widget buildInfantCards(List<QueryDocumentSnapshot> infants, String staffId) {
    return FutureBuilder<Map<String, String>>(
      future: _loadParentNames(infants),
      builder: (context, snapshot) {
        final parentNames = snapshot.data ?? {};

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: infants.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data["name"] ?? "Infant";
            final parentId = data["parentId"] ?? "-";

            final parentName = parentNames[parentId] ?? "Unknown Parent";

            return Container(
              width: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + baby name
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFFFE5EC),
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: accent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Poppins",
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Parent name (instead of parent ID)
                  Text(
                    "Parent: $parentName",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontFamily: "Poppins",
                    ),
                  ),

                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text(
                        "Remove",
                        style: TextStyle(color: Colors.red, fontFamily: "Poppins"),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _removeAssignment(staffId, doc.id, name),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // MAIN UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filtered = staffList
        .where((s) => (s["username"] ?? "")
        .toString()
        .toLowerCase()
        .contains(searchQuery.toLowerCase()))
        .toList();

    filtered.sort((a, b) {
      final aName = (a["username"] ?? "").toString().toLowerCase();
      final bName = (b["username"] ?? "").toString().toLowerCase();
      return sortType == "A-Z" ? aName.compareTo(bName) : bName.compareTo(aName);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),

                // Title + Search
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Staff Management",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade200,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: "Search Staff",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (v) => setState(() => searchQuery = v),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final staff = filtered[i];
                      final staffId = staff["id"];
                      final staffName = staff["username"] ?? "Unnamed Staff";

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ExpansionTile(
                          title: Text(
                            staffName,
                            style: const TextStyle(
                                fontFamily: "Poppins",
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            staff["email"] ?? "",
                            style: const TextStyle(fontFamily: "Poppins"),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () =>
                                _openAssignInfantDialog(staffId, staffName),
                            child: const Text(
                              "Assign Infant",
                              style:
                              TextStyle(color: Colors.white, fontFamily: "Poppins"),
                            ),
                          ),
                          children: [
                            StreamBuilder<QuerySnapshot>(
                              stream: _firestore
                                  .collection("staff")
                                  .doc(staffId)
                                  .collection("infants")
                                  .snapshots(),
                              builder: (context, snap) {
                                if (!snap.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  );
                                }

                                final infants = snap.data!.docs;

                                if (infants.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text("No infants assigned.",
                                        style:
                                        TextStyle(fontFamily: "Poppins")),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: buildInfantCards(infants, staffId),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
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

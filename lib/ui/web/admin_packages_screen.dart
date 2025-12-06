import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'admin_logout_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_report_screen.dart';
import 'admin_staff_screen.dart';

class AdminPackagesScreen extends StatefulWidget {
  const AdminPackagesScreen({Key? key}) : super(key: key);

  @override
  State<AdminPackagesScreen> createState() => _AdminPackagesScreenState();
}

class _AdminPackagesScreenState extends State<AdminPackagesScreen> {
  static const accent = Color(0xFFC2868B);
  static const lightPink = Color(0xFFFADADD);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String adminName = "";
  String adminRole = "Admin";

  // Filters / sorting
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _sortBy = "Name A–Z";
  String _priceFilter = "All";

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
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

  // ---------- NAVIGATION & LOGOUT ----------

  void _navigateTo(String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
        break;
      case 'Staff':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminStaffScreen()),
        );
        break;
      case 'Packages':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminPackagesScreen()),
        );
        break;
      case 'Report':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminReportScreen()),
        );
        break;
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminLogoutScreen()),
            (route) => false,
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // ---------- CRUD HELPERS ----------

  Future<void> _deletePackage(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Delete package?",
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        content: const Text(
          "This action cannot be undone.",
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('package').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Package deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting package: $e')),
      );
    }
  }

  /// Add / Edit package dialog – only saves image filenames (assets), no upload
  Future<void> _showPackageDialog({
    String? docId,
    Map<String, dynamic>? existingData,
  }) async {
    final bool isEdit = docId != null && existingData != null;

    final nameController =
    TextEditingController(text: existingData?['name'] ?? '');
    final priceController = TextEditingController(
        text: existingData?['price'] != null
            ? (existingData!['price']).toString()
            : '');
    final descriptionController =
    TextEditingController(text: existingData?['description'] ?? '');

    // existing filenames from Firestore
    List<String> existingImageNames = [];
    if (existingData?['images'] != null) {
      existingImageNames = List<String>.from(existingData!['images']);
    }

    final imageNamesController = TextEditingController(
      text: existingImageNames.join(', '),
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 600,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? "Edit Package" : "Add Package",
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ----- NAME -----
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Package Name",
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) =>
                      v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 12),

                    // ----- PRICE -----
                    TextFormField(
                      controller: priceController,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Price (RM)",
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Required";
                        }
                        final val = double.tryParse(v.trim());
                        if (val == null || val < 0) {
                          return "Enter valid price";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // ----- DESCRIPTION -----
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "Image filenames (from assets/images/)",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: imageNamesController,
                      decoration: const InputDecoration(
                        hintText: "Example: deluxe1.png, deluxe2.png, deluxe3.png",
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Note: these files must exist in assets/images/ "
                          "and be listed under assets: in pubspec.yaml.",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ----- ACTION BUTTONS -----
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: accent),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            // parse filenames
                            final raw = imageNamesController.text.trim();
                            final List<String> imageList = raw.isEmpty
                                ? []
                                : raw
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();

                            final data = {
                              'name': nameController.text.trim(),
                              'price':
                              double.parse(priceController.text.trim()),
                              'description':
                              descriptionController.text.trim(),
                              'images': imageList,
                            };

                            try {
                              if (isEdit) {
                                await _firestore
                                    .collection('package')
                                    .doc(docId)
                                    .update(data);
                              } else {
                                await _firestore
                                    .collection('package')
                                    .add(data);
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error ${isEdit ? "updating" : "adding"} package: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            isEdit ? "Save" : "Add",
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- SIDEBAR & TOPBAR ----------

  Widget _buildSidebar() {
    final items = [
      {'icon': Icons.dashboard, 'label': 'Dashboard', 'selected': false},
      {'icon': Icons.people, 'label': 'Staff', 'selected': false},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Packages', 'selected': true},
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
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                return ListTile(
                  leading: Icon(
                    item['icon'] as IconData,
                    color: item['selected'] as bool
                        ? Colors.red.shade200
                        : Colors.black54,
                  ),
                  title: Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: item['selected'] as bool
                          ? Colors.red.shade200
                          : Colors.black87,
                      fontWeight: item['selected'] as bool
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () => _navigateTo(item['label'] as String),
                );
              },
            ),
          ),
          Divider(color: Colors.grey[300]),
          ListTile(
            leading:
            const Icon(Icons.power_settings_new, color: Colors.black54),
            title: const Text('Logout', style: TextStyle(fontFamily: 'Poppins')),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

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
                    fontFamily: 'Poppins'),
              ),
              Text(
                adminRole,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontFamily: 'Poppins'),
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
                    builder: (context) => const AdminProfileScreen(),
                  ),
                );
              } else if (value == "logout") {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "profile", child: Text("Profile")),
              PopupMenuItem(value: "logout", child: Text("Logout")),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- FILTER & SORT ----------

  List<Map<String, dynamic>> _applyFilters(List<QueryDocumentSnapshot> docs) {
    final List<Map<String, dynamic>> list = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'description': data['description'] ?? '',
        'price': (data['price'] as num?)?.toDouble() ?? 0.0,
        'images': List<String>.from(data['images'] ?? []),
      };
    }).toList();

    final String query = _searchQuery.toLowerCase();

    // Search by name
    var filtered = list.where((pkg) {
      final name = (pkg['name'] as String).toLowerCase();
      return name.contains(query);
    }).toList();

    // Price filter
    filtered = filtered.where((pkg) {
      final price = pkg['price'] as double;
      switch (_priceFilter) {
        case "Below RM 3000":
          return price < 3000;
        case "RM 3000 - RM 6000":
          return price >= 3000 && price <= 6000;
        case "Above RM 6000":
          return price > 6000;
        default:
          return true;
      }
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case "Name A–Z":
          return (a['name'] as String)
              .toLowerCase()
              .compareTo((b['name'] as String).toLowerCase());
        case "Name Z–A":
          return (b['name'] as String)
              .toLowerCase()
              .compareTo((a['name'] as String).toLowerCase());
        case "Price Low–High":
          return (a['price'] as double).compareTo(b['price'] as double);
        case "Price High–Low":
          return (b['price'] as double).compareTo(a['price'] as double);
      }
      return 0;
    });

    return filtered;
  }

  // ---------- MAIN BUILD ----------

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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + Sort + Add button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Packages',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade200,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Row(
                              children: [
                                // Sort dropdown
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButton<String>(
                                    value: _sortBy,
                                    underline: const SizedBox(),
                                    icon: const Icon(
                                        Icons.keyboard_arrow_down_outlined),
                                    items: const [
                                      DropdownMenuItem(
                                          value: "Name A–Z",
                                          child: Text("Name A–Z")),
                                      DropdownMenuItem(
                                          value: "Name Z–A",
                                          child: Text("Name Z–A")),
                                      DropdownMenuItem(
                                          value: "Price Low–High",
                                          child: Text("Price Low–High")),
                                      DropdownMenuItem(
                                          value: "Price High–Low",
                                          child: Text("Price High–Low")),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _sortBy = value);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add,
                                      color: Colors.white),
                                  label: const Text(
                                    "Add Package",
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Colors.white),
                                  ),
                                  onPressed: () => _showPackageDialog(),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Search + Filter row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                        Colors.black.withOpacity(0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    setState(
                                            () => _searchQuery = value.trim());
                                  },
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.search,
                                        color: Colors.grey.shade500),
                                    hintText: "Search by package name",
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3)),
                                ],
                              ),
                              child: DropdownButton<String>(
                                value: _priceFilter,
                                underline: const SizedBox(),
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_outlined),
                                items: const [
                                  DropdownMenuItem(
                                      value: "All", child: Text("All Prices")),
                                  DropdownMenuItem(
                                      value: "Below RM 3000",
                                      child: Text("Below RM 3000")),
                                  DropdownMenuItem(
                                      value: "RM 3000 - RM 6000",
                                      child: Text("RM 3000 - RM 6000")),
                                  DropdownMenuItem(
                                      value: "Above RM 6000",
                                      child: Text("Above RM 6000")),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _priceFilter = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = "";
                                  _priceFilter = "All";
                                  _sortBy = "Name A–Z";
                                });
                              },
                              child: const Text(
                                "Reset",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.black54),
                              ),
                            )
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Package grid
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream:
                            _firestore.collection('package').snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return const Center(
                                  child: Text(
                                    "No packages available.",
                                    style: TextStyle(
                                        fontFamily: 'Poppins', fontSize: 16),
                                  ),
                                );
                              }

                              final filtered =
                              _applyFilters(snapshot.data!.docs);

                              if (filtered.isEmpty) {
                                return const Center(
                                  child: Text(
                                    "No packages match the filter.",
                                    style: TextStyle(
                                        fontFamily: 'Poppins', fontSize: 16),
                                  ),
                                );
                              }

                              return GridView.builder(
                                gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: 1.15,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final pkg = filtered[index];
                                  return _PackageCard(
                                    data: pkg,
                                    accent: accent,
                                    lightPink: lightPink,
                                    onEdit: () => _showPackageDialog(
                                      docId: pkg['id'],
                                      existingData: pkg,
                                    ),
                                    onDelete: () => _deletePackage(pkg['id']),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
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
}

// ---------- CARD WIDGET WITH SAFE LAYOUT (NO OVERFLOW) ----------

class _PackageCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color accent;
  final Color lightPink;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PackageCard({
    Key? key,
    required this.data,
    required this.accent,
    required this.lightPink,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  int _currentImage = 0;

  @override
  Widget build(BuildContext context) {
    final List<String> images = List<String>.from(widget.data['images'] ?? []);
    final String name = widget.data['name'] ?? '';
    final double price = (widget.data['price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.lightPink),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // ---------------- IMAGE CAROUSEL ----------------
          SizedBox(
            height: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: images.isEmpty
                  ? Container(
                color: widget.lightPink.withOpacity(0.4),
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 40, color: Colors.black38),
                ),
              )
                  : Stack(
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentImage = i),
                    itemBuilder: (_, index) {
                      return Image.asset(
                        "assets/images/${images[index]}",
                        fit: BoxFit.cover,
                      );
                    },
                  ),

                  // ● ● ● page indicator
                  Positioned(
                    bottom: 5,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (i) {
                        bool active = i == _currentImage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin:
                          const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 10 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? widget.accent
                                : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }),
                    ),
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ---------------- PACKAGE NAME ----------------
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Poppins",
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: widget.accent,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ---------------- PRICE ----------------
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "RM ${price.toStringAsFixed(2)}",
              style: const TextStyle(
                fontFamily: "Poppins",
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ---------------- EDIT / DELETE BUTTONS ----------------
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onEdit,
                    icon: Icon(Icons.edit,
                        size: 16, color: widget.accent),
                    label: Text("Edit",
                        style: TextStyle(
                            fontFamily: 'Poppins', color: widget.accent)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 40),
                      side: BorderSide(color: widget.accent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.white),
                    label: const Text("Delete",
                        style:
                        TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 40),
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_dashboard_screen.dart';
import 'admin_inventory_screen.dart';
import 'admin_logout_screen.dart';
import 'admin_meal_screen.dart';
import 'admin_packages_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_report_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_scheduling_screen.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  static const accent = Color(0xFFC2868B);
  static const lightPink = Color(0xFFFADADD);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String adminName = "";
  String adminRole = "";

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminInfo() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _firestore.collection('admin').doc(uid).get();
    if (doc.exists) {
      setState(() {
        adminName = doc['name'] ?? "";
        adminRole = doc['role'] ?? "Admin";
      });
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

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  String _formatDate(DateTime d) {
    return DateFormat('d MMM yyyy').format(d);
  }

  String _formatCurrency(num amount) {
    return 'RM ${amount.toStringAsFixed(2)}';
  }

  Future<void> _updateBookingStatus(
      String parentId, String bookingId, String newStatus) async {
    try {
      await _firestore
          .collection("parent")
          .doc(parentId)
          .collection("bookings")
          .doc(bookingId)
          .update({"status": newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Booking $newStatus successfully"),
            backgroundColor: newStatus == "APPROVED" ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateTo(String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
        break;
      case 'Staff':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminStaffScreen()),
        );
        break;
      case 'Scheduling':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminSchedulingScreen()),
        );
        break;
      case 'Packages':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminPackagesScreen()),
        );
        break;
      case 'Meal':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminMealScreen()),
        );
        break;
      case 'Inventory':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminInventoryScreen()),
        );
        break;
      case 'Bookings':
        break; // Already here
      case 'Report':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminReportScreen()),
        );
        break;
    }
  }

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
                _buildFilters(),
                Expanded(
                  child: _buildBookingsList(),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  fontFamily: "Poppins",
                ),
              ),
              Text(
                adminRole.isEmpty ? "Admin" : adminRole,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontFamily: "Poppins",
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
                  MaterialPageRoute(
                    builder: (_) => const AdminProfileScreen(),
                  ),
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

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by parent name or booking ID...",
                prefixIcon: const Icon(Icons.search, color: accent),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F1F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontFamily: "Poppins"),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F1F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _selectedStatus,
              underline: Container(),
              icon: const Icon(Icons.arrow_drop_down, color: accent),
              items: ['All', 'PENDING', 'APPROVED', 'REJECTED']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(
                          status,
                          style: const TextStyle(fontFamily: "Poppins"),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection("parent").snapshots(),
      builder: (context, parentSnapshot) {
        if (!parentSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          );
        }

        final parents = parentSnapshot.data!.docs;
        if (parents.isEmpty) {
          return const Center(
            child: Text(
              "No bookings found",
              style: TextStyle(fontFamily: "Poppins"),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: parents.length,
          itemBuilder: (context, index) {
            final parentDoc = parents[index];
            final parentId = parentDoc.id;
            final parentName = (parentDoc['username'] ?? "Unnamed Parent")
                .toString()
                .toLowerCase();

            // Filter by search query
            if (_searchQuery.isNotEmpty &&
                !parentName.contains(_searchQuery)) {
              return const SizedBox.shrink();
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection("parent")
                  .doc(parentId)
                  .collection("bookings")
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, bookingSnapshot) {
                if (!bookingSnapshot.hasData ||
                    bookingSnapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final bookings = bookingSnapshot.data!.docs.where((b) {
                  final status = (b['status'] ?? 'PENDING').toString();
                  if (_selectedStatus != 'All' &&
                      status != _selectedStatus) {
                    return false;
                  }
                  return true;
                }).toList();

                if (bookings.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildParentHeader(parentDoc['username'] ?? "Parent"),
                    ...bookings.map((booking) => _buildBookingCard(
                          booking.data() as Map<String, dynamic>,
                          parentId,
                          booking.id,
                        )),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildParentHeader(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: lightPink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(
              fontFamily: "Poppins",
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
      Map<String, dynamic> booking, String parentId, String bookingId) {
    final status = (booking['status'] ?? 'PENDING').toString();
    final packages = booking['packages'] as List? ?? [];
    final package = packages.isNotEmpty ? packages[0] : {};
    final totalPayable = (booking['totalPayable'] ?? 0).toDouble();
    final checkIn = _parseDate(booking['checkInDate']);
    final checkOut = _parseDate(booking['checkOutDate']);
    final paymentMethod = booking['paymentMethod'] ?? 'N/A';
    final stayMonths = booking['stayLengthMonths'] ?? 1;

    Color statusColor;
    IconData statusIcon;
    switch (status.toUpperCase()) {
      case 'APPROVED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withOpacity(0.1),
                  statusColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package['name'] ?? 'Package',
                        style: const TextStyle(
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontFamily: "Poppins",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(totalPayable),
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.calendar_today,
                  "Check-in",
                  _formatDate(checkIn),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.calendar_today_outlined,
                  "Check-out",
                  _formatDate(checkOut),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.access_time,
                  "Duration",
                  "$stayMonths month${stayMonths > 1 ? 's' : ''}",
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.payment,
                  "Payment Method",
                  paymentMethod,
                ),
                if (package['location'] != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.location_on,
                    "Location",
                    package['location'],
                  ),
                ],
              ],
            ),
          ),

          // Actions
          if (status == 'PENDING')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F1F3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmAction(
                        parentId,
                        bookingId,
                        "REJECTED",
                        "Are you sure you want to reject this booking?",
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text(
                        "Reject",
                        style: TextStyle(fontFamily: "Poppins"),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmAction(
                        parentId,
                        bookingId,
                        "APPROVED",
                        "Are you sure you want to approve this booking?",
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        "Approve",
                        style: TextStyle(fontFamily: "Poppins"),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 12),
        Text(
          "$label: ",
          style: TextStyle(
            fontFamily: "Poppins",
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: "Poppins",
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmAction(String parentId, String bookingId, String status,
      String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "Confirm Action",
          style: TextStyle(fontFamily: "Poppins", fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: "Poppins"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(fontFamily: "Poppins"),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == "APPROVED" ? Colors.green : Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateBookingStatus(parentId, bookingId, status);
            },
            child: Text(
              status == "APPROVED" ? "Approve" : "Reject",
              style: const TextStyle(
                color: Colors.white,
                fontFamily: "Poppins",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    List<Map<String, dynamic>> sidebarItems = [
      {'icon': Icons.dashboard, 'label': 'Dashboard', 'selected': false},
      {'icon': Icons.people, 'label': 'Staff', 'selected': false},
      {'icon': Icons.schedule, 'label': 'Scheduling', 'selected': false},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Packages', 'selected': false},
      {'icon': Icons.set_meal_outlined, 'label': 'Meal', 'selected': false},
      {'icon': Icons.inventory_2_outlined, 'label': 'Inventory', 'selected': false},
      {'icon': Icons.book_online, 'label': 'Bookings', 'selected': true},
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
                return _buildSidebarButton(
                  icon: item['icon'],
                  label: item['label'],
                  selected: item['selected'],
                  onTap: () {
                    _navigateTo(item['label']);
                  },
                );
              },
            ),
          ),
          Divider(color: Colors.grey[300]),
          ListTile(
            leading: const Icon(Icons.power_settings_new, color: Colors.black54),
            title: const Text(
              "Logout",
              style: TextStyle(fontFamily: "Poppins"),
            ),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebarButton({
    required IconData icon,
    required String label,
    required bool selected,
    required Function onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? Colors.red.shade200 : Colors.black54,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          color: selected ? Colors.red.shade200 : Colors.black87,
        ),
      ),
      onTap: () => onTap(),
    );
  }
}


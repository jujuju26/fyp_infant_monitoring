import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'staff_booking_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffBookingsScreen extends StatefulWidget {
  const StaffBookingsScreen({Key? key}) : super(key: key);

  @override
  _StaffBookingsScreenState createState() => _StaffBookingsScreenState();
}

class _StaffBookingsScreenState extends State<StaffBookingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatDate(DateTime d) {
    return DateFormat('d MMM yyyy').format(d);
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  String _formatCurrency(num amount) {
    return 'RM ${amount.toStringAsFixed(2)}';
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).popUntil((route) => route.isFirst);
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

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Booking $newStatus"),
          backgroundColor:
          newStatus == "APPROVED" ? Colors.green : Colors.redAccent,
        ),
      );
    } catch (e) {
      print("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.white),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/logo2.png', height: 70),
                      const SizedBox(height: 10),
                      const Text(
                        'Caring made simple',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Color(0xFFC2868B),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Color(0xFFC2868B)),
                title: const Text('Past Bookings', style: TextStyle(fontFamily: 'Poppins')),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffBookingHistoryScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFC2868B)),
                title: const Text('Logout', style: TextStyle(fontFamily: 'Poppins')),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFFC2868B)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset('assets/images/logo2.png', height: 40),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection("parent").snapshots(),
        builder: (context, parentSnapshot) {
          if (!parentSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFC2868B)),
            );
          }

          final parents = parentSnapshot.data!.docs;

          if (parents.isEmpty) {
            return const Center(
              child: Text("No bookings found.", style: TextStyle(fontFamily: "Poppins")),
            );
          }

          return Container(
            color: Colors.white,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: parents.length,
              itemBuilder: (context, index) {
                final parentDoc = parents[index];
                final parentId = parentDoc.id;
                final parentName = parentDoc['username'] ?? "Unnamed Parent";

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection("parent")
                      .doc(parentId)
                      .collection("bookings")
                      .snapshots(),
                  builder: (context, bookingSnap) {
                    if (!bookingSnap.hasData || bookingSnap.data!.docs.isEmpty) {
                      return Container();
                    }

                    final bookings = bookingSnap.data!.docs;

                    // Filter out bookings where checkInDate is in the past
                    final futureBookings = bookings.where((b) {
                      final checkIn = _parseDate(b['checkInDate']);
                      return checkIn.isAfter(DateTime.now());
                    }).toList();

                    if (futureBookings.isEmpty) {
                      return const Center(
                        child: Text("No future bookings found.", style: TextStyle(fontFamily: "Poppins")),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _parentHeader(parentName),
                        ...futureBookings.map((b) =>
                            _bookingCard(b.data() as Map<String, dynamic>, parentId, b.id)),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _parentHeader(String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        "👤 $name",
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFFC2868B),
        ),
      ),
    );
  }

  Widget _bookingCard(
      Map<String, dynamic> booking, String parentId, String bookingId) {
    final package = booking["packages"]?[0] ?? {};

    final String status =
    (booking["status"] ?? "PENDING").toString().toUpperCase();

    final Color statusColor = status == "APPROVED"
        ? Colors.green
        : status == "REJECTED"
        ? Colors.red
        : Colors.orange;

    final DateTime checkIn = _parseDate(booking["checkInDate"]);
    final DateTime checkOut = _parseDate(booking["checkOutDate"]);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFADADD),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.child_care, color: Color(0xFFC2868B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  package["name"] ?? "Package",
                  style: const TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),

              // Animated Status Badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Container(
                  key: ValueKey(status),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(status,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _detailRow(Icons.calendar_today, "Check-in", _formatDate(checkIn)),
          _detailRow(Icons.calendar_month, "Check-out", _formatDate(checkOut)),
          _detailRow(Icons.shopping_bag, "Quantity",
              "${package['quantity'] ?? 1}"),
          _detailRow(Icons.attach_money, "Price",
              _formatCurrency((package["price"] ?? 0).toDouble())),

          const SizedBox(height: 12),

          // Animated Buttons
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: status == "PENDING"
                ? Row(
              key: const ValueKey("buttons"),
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => _updateBookingStatus(
                      parentId, bookingId, "REJECTED"),
                  child: const Text("REJECT",
                      style: TextStyle(fontFamily: "Poppins")),
                ),
                const SizedBox(width: 10),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => _updateBookingStatus(
                      parentId, bookingId, "APPROVED"),
                  child: const Text("APPROVE",
                      style: TextStyle(fontFamily: "Poppins")),
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Color(0xFFC2868B)),
          const SizedBox(width: 8),
          Text("$label: ",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontFamily: "Poppins")),
          Text(value, style: const TextStyle(fontFamily: "Poppins")),
        ],
      ),
    );
  }
}

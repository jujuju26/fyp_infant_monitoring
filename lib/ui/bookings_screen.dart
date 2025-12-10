import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'meal_planner_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({Key? key}) : super(key: key);

  @override
  _BookingsScreenState createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------------------------------
  // Helpers
  // -------------------------------
  String _formatDate(DateTime d) =>
      DateFormat('d MMMM yyyy').format(d);

  String _formatCurrency(double amount) =>
      'RM ${amount.toStringAsFixed(2)}';

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // -------------------------------
  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;
    if (user == null) {
      return _buildNotLoggedIn();
    }

    final Stream<QuerySnapshot> bookingsStream = _firestore
        .collection('parent')
        .doc(user.uid)
        .collection('bookings')
        .orderBy('checkInDate')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFFC2868B),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: bookingsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFC2868B)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmpty();
          }

          final rawBookings = snapshot.data!.docs;

          // Attach ID and convert to list
          final bookings = rawBookings.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort by check-in
          bookings.sort((a, b) {
            return _parseDate(a['checkInDate'])
                .compareTo(_parseDate(b['checkInDate']));
          });

          return _buildGroupedBookings(bookings);
        },
      ),
    );
  }

  // -------------------------------
  // Not Logged In UI
  // -------------------------------
  Widget _buildNotLoggedIn() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFFC2868B),
      ),
      body: const Center(
        child: Text('You are not logged in.',
            style: TextStyle(fontFamily: 'Poppins')),
      ),
    );
  }

  // -------------------------------
  // Empty State UI
  // -------------------------------
  Widget _buildEmpty() {
    return const Center(
      child: Text('No bookings found.', style: TextStyle(fontFamily: 'Poppins')),
    );
  }

  // -------------------------------
  // Group Bookings Into Sections
  // -------------------------------
  Widget _buildGroupedBookings(List<Map<String, dynamic>> bookings) {
    final now = DateTime.now();
    List<Map<String, dynamic>> past = [];
    List<Map<String, dynamic>> future = [];

    for (var booking in bookings) {
      if (_parseDate(booking['checkInDate']).isBefore(now)) {
        past.add(booking);
      } else {
        future.add(booking);
      }
    }

    Map<String, dynamic>? nextAppointment;
    List<Map<String, dynamic>> upcoming = [];

    if (future.isNotEmpty) {
      nextAppointment = future.first;
      if (future.length > 1) {
        upcoming = future.sublist(1);
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nextAppointment != null)
            _buildSectionTitle("⚡ Your Next Appointment"),
          if (nextAppointment != null)
            _buildBookingCard(nextAppointment!, true),

          if (upcoming.isNotEmpty)
            _buildSectionTitle("📅 Upcoming Appointments"),
          ...upcoming.map((b) => _buildBookingCard(b, true)),

          if (past.isNotEmpty)
            _buildSectionTitle("📚 Appointment History"),
          ...past.map((b) => _buildBookingCard(b, false)),
        ],
      ),
    );
  }

  // -------------------------------
  // Section Title UI
  // -------------------------------
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 20, bottom: 5),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Color(0xFFC2868B),
        ),
      ),
    );
  }

  // -------------------------------
  // Booking Card UI
  // -------------------------------
  Widget _buildBookingCard(Map<String, dynamic> booking, bool allowCancel) {
    final String status = (booking['status'] ?? 'PENDING').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFADADD),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBookingDetails(booking),

          const SizedBox(height: 12),

          // ⭐ SHOW MEAL PLANNER ONLY IF STATUS == APPROVED
          if (status == "APPROVED")
            _buildMealPlannerButton(booking['id']),

          if (allowCancel)
            _buildCancelButton(booking['id']),
        ],
      ),
    );
  }

  // -------------------------------
  // Booking Details UI
  // -------------------------------
  Widget _buildBookingDetails(Map<String, dynamic> booking) {
    final package = booking['packages']?[0] ?? {};

    final String status = (booking['status'] ?? 'PENDING').toString().toUpperCase();
    final DateTime checkIn = _parseDate(booking['checkInDate']);
    final DateTime checkOut = _parseDate(booking['checkOutDate']);

    final String packageName = package['name'] ?? "Package";
    final double price = (package['price'] ?? 0).toDouble();
    final int qty = package['quantity'] ?? 1;

    Color statusColor = Colors.orange;
    if (status == 'APPROVED') statusColor = Colors.green;
    if (status == 'REJECTED') statusColor = Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          packageName,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 6),
            Text("Check-in: ${_formatDate(checkIn)}"),
          ],
        ),

        const SizedBox(height: 6),

        Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 6),
            Text("Check-out: ${_formatDate(checkOut)}"),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(Icons.production_quantity_limits,
                size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 6),
            Text("Quantity: $qty"),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(Icons.attach_money,
                size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 6),
            Text("Price: ${_formatCurrency(price)}"),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // -------------------------------
  // Meal Planner Button
  // -------------------------------
  Widget _buildMealPlannerButton(String bookingId) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFC2868B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MealPlannerScreen(bookingId: bookingId),
          ),
        );
      },
      child: const Text(
        "Meal Planner",
        style: TextStyle(
          fontFamily: "Poppins",
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  // -------------------------------
  // Cancel Button
  // -------------------------------
  Widget _buildCancelButton(String bookingId) {
    return TextButton(
      onPressed: () async {
        bool confirmed = await _showCancelConfirmationDialog();
        if (confirmed) _cancelBooking(bookingId);
      },
      child: const Text(
        'Cancel Booking',
        style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins'),
      ),
    );
  }

  // Confirm Cancel Popup
  Future<bool> _showCancelConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content:
        const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
        ],
      ),
    ) ??
        false;
  }

  // Delete booking
  Future<void> _cancelBooking(String bookingId) async {
    try {
      await _firestore
          .collection('parent')
          .doc(_auth.currentUser!.uid)
          .collection('bookings')
          .doc(bookingId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel booking.')),
      );
    }
  }
}

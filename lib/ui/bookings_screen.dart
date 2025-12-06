import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({Key? key}) : super(key: key);

  @override
  _BookingsScreenState createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatDate(DateTime d) {
    return DateFormat('d MMMM yyyy').format(d);
  }

  String _formatCurrency(double amount) {
    return 'RM ${amount.toStringAsFixed(2)}';
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    if (user == null) {
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
              child: CircularProgressIndicator(color: Color(0xFFC2868B)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No bookings found.',
                  style: TextStyle(fontFamily: 'Poppins')),
            );
          }

          final bookings = snapshot.data!.docs;

          // Parse + sort
          final sortedBookings = bookings.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList()
            ..sort((a, b) {
              return _parseDate(a['checkInDate'])
                  .compareTo(_parseDate(b['checkInDate']));
            });

          final DateTime now = DateTime.now();

          // GROUPING
          List<Map<String, dynamic>> past = [];
          List<Map<String, dynamic>> future = [];

          for (var booking in sortedBookings) {
            DateTime checkIn = _parseDate(booking['checkInDate']);
            if (checkIn.isBefore(now)) {
              past.add(booking);
            } else {
              future.add(booking);
            }
          }

          // NEXT + UPCOMING
          Map<String, dynamic>? nextAppointment;
          List<Map<String, dynamic>> upcomingAppointments = [];

          if (future.isNotEmpty) {
            nextAppointment = future.first;
            if (future.length > 1) {
              upcomingAppointments = future.sublist(1);
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NEXT APPOINTMENT
                if (nextAppointment != null)
                  _buildSectionTitle("⚡ Your Next Appointment"),
                if (nextAppointment != null)
                  _buildBookingCard(nextAppointment, true),

                // UPCOMING APPOINTMENTS
                if (upcomingAppointments.isNotEmpty)
                  _buildSectionTitle("📅 Upcoming Appointments"),
                ...upcomingAppointments.map((b) =>
                    _buildBookingCard(b, true)),

                // HISTORY
                if (past.isNotEmpty)
                  _buildSectionTitle("📚 Appointment History"),
                ...past.map((b) => _buildBookingCard(b, false)),
              ],
            ),
          );
        },
      ),
    );
  }

  // SECTION HEADER
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

  // BOOKING CARD UI
  Widget _buildBookingCard(Map<String, dynamic> booking, bool allowCancel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFADADD),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBookingDetails(booking),

          if (allowCancel)
            _buildCancelButton(booking['id']),
        ],
      ),
    );
  }

  // CANCEL BUTTON
  Widget _buildCancelButton(String bookingId) {
    return TextButton(
      onPressed: () async {
        bool confirmCancel = await _showCancelConfirmationDialog();
        if (confirmCancel) {
          _cancelBooking(bookingId);
        }
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

  // CONFIRMATION POPUP
  Future<bool> _showCancelConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Cancellation'),
          content: const Text('Are you sure you want to cancel this booking?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // DELETE BOOKING
  Future<void> _cancelBooking(String bookingId) async {
    try {
      await _firestore
          .collection('parent')
          .doc(_auth.currentUser!.uid)
          .collection('bookings')
          .doc(bookingId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking has been cancelled.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel booking.')),
      );
    }
  }

  // BOOKING DETAILS UI
  Widget _buildBookingDetails(Map<String, dynamic> bookingData) {
    final package = bookingData['packages']?[0] ?? {};
    final String status = (bookingData['status'] ?? 'PENDING').toString();

    final DateTime checkInDate = _parseDate(bookingData['checkInDate']);
    final DateTime checkOutDate = _parseDate(bookingData['checkOutDate']);
    final String packageName = package['name'] ?? 'No package name';
    final double price = (package['price'] ?? 0).toDouble();
    final int quantity = package['quantity'] ?? 1;

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
              fontSize: 16),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 6),
            Text('Check-in: ${_formatDate(checkInDate)}'),
          ],
        ),

        const SizedBox(height: 6),

        Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 6),
            Text('Check-out: ${_formatDate(checkOutDate)}'),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(Icons.production_quantity_limits,
                size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 6),
            Text('Quantity: $quantity'),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(Icons.attach_money,
                size: 18, color: Color(0xFFC2868B)),
            const SizedBox(width: 6),
            Text('Price: ${_formatCurrency(price)}'),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status.toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        )
      ],
    );
  }
}

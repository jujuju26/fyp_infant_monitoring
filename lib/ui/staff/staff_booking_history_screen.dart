import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StaffBookingHistoryScreen extends StatelessWidget {
  const StaffBookingHistoryScreen({Key? key}) : super(key: key);

  // -------------------------
  // DATE HELPERS
  // -------------------------

  /// FORMAT TO: "6 Dec 2025"
  String _formatDate(DateTime d) {
    return DateFormat('d MMM yyyy').format(d);
  }

  /// SAFE PARSER: handles Timestamp, ISO string, or fallback.
  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    try {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.parse(value);
      }
    } catch (_) {}

    return DateTime.now();
  }

  /// TRUE if date < today (ignoring time).
  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(date.year, date.month, date.day);
    return bookingDay.isBefore(today);
  }

  // -------------------------
  // MAIN BUILD
  // -------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          "Booking History",
          style: TextStyle(
            fontFamily: "Poppins",
            color: Color(0xFFC2868B),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFC2868B)),
      ),

      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection("parent").snapshots(),
        builder: (context, parentSnap) {
          if (!parentSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final parents = parentSnap.data!.docs;
          List<Widget> historyWidgets = [];

          for (var parent in parents) {
            final String parentId = parent.id;
            final String parentName = parent['username'] ?? "Parent";

            // -------------------------
            // PARENT HEADER
            // -------------------------
            historyWidgets.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                child: Text(
                  "👤 $parentName",
                  style: const TextStyle(
                    fontFamily: "Poppins",
                    color: Color(0xFFC2868B),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );

            // -------------------------
            // STREAM: bookings
            // -------------------------
            historyWidgets.add(
              StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection("parent")
                    .doc(parentId)
                    .collection("bookings")
                    .where("status", whereIn: ["APPROVED", "REJECTED"])
                    .snapshots(),
                builder: (context, bookSnap) {
                  if (!bookSnap.hasData) return Container();

                  final bookings = bookSnap.data!.docs;
                  if (bookings.isEmpty) return Container();

                  List<Widget> bookingCards = [];

                  for (var booking in bookings) {
                    final data = booking.data() as Map<String, dynamic>;
                    final packages = data["packages"];

                    if (packages == null || packages.isEmpty) continue;

                    final pkg = packages[0];
                    final checkInRaw = data["checkInDate"];
                    final checkOutRaw = data["checkOutDate"];

                    final DateTime checkInDate = _parseDate(checkInRaw);
                    final DateTime checkOutDate = _parseDate(checkOutRaw);

                    // ⭐ ONLY SHOW IF check-in < today
                    if (!_isPastDate(checkInDate)) continue;

                    // -------------------------
                    // BOOKING CARD
                    // -------------------------
                    bookingCards.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFADADD),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(0, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // PACKAGE NAME
                              Row(
                                children: [
                                  const Icon(Icons.local_offer, color: Color(0xFFC2868B)),
                                  const SizedBox(width: 8),
                                  Text(
                                    pkg["name"] ?? "Package",
                                    style: const TextStyle(
                                      fontFamily: "Poppins",
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // CHECK-IN
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Check-in: ${_formatDate(checkInDate)}",
                                    style: const TextStyle(fontFamily: "Poppins"),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // CHECK-OUT
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Check-out: ${_formatDate(checkOutDate)}",
                                    style: const TextStyle(fontFamily: "Poppins"),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // STATUS
                              Row(
                                children: [
                                  Icon(
                                    data["status"] == "APPROVED"
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: data["status"] == "APPROVED"
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Status: ${data["status"]}",
                                    style: TextStyle(
                                      fontFamily: "Poppins",
                                      fontWeight: FontWeight.bold,
                                      color: data["status"] == "APPROVED"
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (bookingCards.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "No past bookings.",
                        style: TextStyle(fontFamily: "Poppins", color: Colors.black54),
                      ),
                    );
                  }

                  return Column(children: bookingCards);
                },
              ),
            );
          }

          return ListView(children: historyWidgets);
        },
      ),
    );
  }
}

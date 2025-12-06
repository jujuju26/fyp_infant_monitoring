import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StaffBookingHistoryScreen extends StatelessWidget {
  const StaffBookingHistoryScreen({Key? key}) : super(key: key);

  String _formatDate(DateTime d) {
    return DateFormat('d MMM yyyy').format(d);
  }

  DateTime _parseDate(dynamic value) {
    print("Parsing date: $value");
    if (value == null) {
      print("Date is null!");
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      try {
        DateTime parsedDate = DateTime.parse(value);
        print("Parsed Date: $parsedDate");
        return parsedDate;
      } catch (e) {
        print("Error parsing date: $e");
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

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

          for (var p in parents) {
            final parentId = p.id;
            final parentName = p['username'] ?? "Parent";

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

                  return Column(
                    children: bookings.map((b) {
                      final data = b.data() as Map<String, dynamic>;
                      final packages = data["packages"];

                      print("Packages: $packages");

                      if (packages != null && packages.isNotEmpty) {
                        final package = packages[0] ?? {};

                        final inDate = data["checkInDate"];
                        final outDate = data["checkOutDate"];

                        print("checkInDate: $inDate");
                        print("checkOutDate: $outDate");

                        final DateTime parsedInDate = _parseDate(inDate);
                        final DateTime parsedOutDate = _parseDate(outDate);

                        print("Parsed Check-in Date: ${_formatDate(parsedInDate)}");

                        // ⭐ Only show past bookings (based on CHECK-IN date only)
                        if (!parsedInDate.isBefore(DateTime.now())) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
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
                                Row(
                                  children: [
                                    const Icon(Icons.local_offer,
                                        color: Color(0xFFC2868B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      package["name"] ?? "Package",
                                      style: const TextStyle(
                                        fontFamily: "Poppins",
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 18, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Check-in: ${_formatDate(parsedInDate)}",
                                      style: const TextStyle(fontFamily: "Poppins"),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 18, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Check-out: ${_formatDate(parsedOutDate)}",
                                      style: const TextStyle(fontFamily: "Poppins"),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

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
                        );
                      } else {
                        print("No packages found or packages is null");
                        return const SizedBox.shrink();
                      }
                    }).toList(),
                  );
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

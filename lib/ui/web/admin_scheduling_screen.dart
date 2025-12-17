import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_dashboard_screen.dart';
import 'admin_inventory_screen.dart';
import 'admin_meal_screen.dart';
import 'admin_packages_screen.dart';
import 'admin_report_screen.dart';
import 'admin_logout_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_staff_screen.dart';

class AdminSchedulingScreen extends StatefulWidget {
  const AdminSchedulingScreen({Key? key}) : super(key: key);

  @override
  _AdminSchedulingScreenState createState() => _AdminSchedulingScreenState();
}

class _AdminSchedulingScreenState extends State<AdminSchedulingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const accent = Color(0xFFC2868B);
  static const lightPink = Color(0xFFFADADD);

  // Admin info
  String adminName = "";
  String adminRole = "Admin";

  // View mode: 'week' or 'month'
  String viewMode = 'week';

  // Current date for navigation
  DateTime currentDate = DateTime.now();

  // Staff list
  List<Map<String, dynamic>> staffList = [];

  // Shifts data
  Map<String, List<Map<String, dynamic>>> shiftsByDate = {};

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _fetchStaff();
    _fetchShifts();
  }

  Future<void> _loadAdminInfo() async {
    try {
      final uid = _auth.currentUser!.uid;
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

  Future<void> _fetchShifts() async {
    try {
      final shiftsSnapshot = await _firestore
          .collection('shifts')
          .orderBy('startTime')
          .get();

      Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var doc in shiftsSnapshot.docs) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        final dateKey = DateFormat('yyyy-MM-dd').format(startTime);

        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }

        grouped[dateKey]!.add({
          'id': doc.id,
          ...data,
          'startTime': startTime,
          'endTime': (data['endTime'] as Timestamp).toDate(),
        });
      }

      setState(() {
        shiftsByDate = grouped;
      });
    } catch (e) {
      debugPrint("Error fetching shifts: $e");
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLogoutScreen()),
      (route) => false,
    );
  }

  void _navigateTo(String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
        break;
      case 'Staff':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => AdminStaffScreen()));
        break;
      case 'Packages':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminPackagesScreen()));
        break;
      case 'Meal':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AdminMealScreen()));
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
      case 'Scheduling':
        break;
    }
  }

  Widget _buildSidebar() {
    List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.people, 'label': 'Staff'},
      {'icon': Icons.schedule, 'label': 'Scheduling'},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Packages'},
      {'icon': Icons.set_meal_outlined, 'label': 'Meal'},
      {'icon': Icons.inventory_2_outlined, 'label': 'Inventory'},
      {'icon': Icons.book_online, 'label': 'Bookings'},
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
                bool selected = item['label'] == "Scheduling";
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

  List<DateTime> _getWeekDates(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  List<DateTime> _getMonthDates(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final startOfWeek = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final endOfWeek = lastDay.add(Duration(days: 7 - lastDay.weekday));

    List<DateTime> dates = [];
    for (var d = startOfWeek; d.isBefore(endOfWeek.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
      dates.add(d);
    }
    return dates;
  }

  bool _hasConflict(Map<String, dynamic> newShift, String? excludeShiftId) {
    final newStart = newShift['startTime'] as DateTime;
    final newEnd = newShift['endTime'] as DateTime;
    final staffId = newShift['staffId'] as String;

    for (var dateKey in shiftsByDate.keys) {
      final date = DateTime.parse(dateKey);
      if (date.year == newStart.year && date.month == newStart.month && date.day == newStart.day) {
        for (var existingShift in shiftsByDate[dateKey]!) {
          if (excludeShiftId != null && existingShift['id'] == excludeShiftId) {
            continue;
          }
          if (existingShift['staffId'] == staffId) {
            final existingStart = existingShift['startTime'] as DateTime;
            final existingEnd = existingShift['endTime'] as DateTime;

            // Check for overlap
            if ((newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart))) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  void _showCreateShiftDialog() {
    String? selectedStaffId;
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay(
      hour: (TimeOfDay.now().hour + 2) % 24,
      minute: TimeOfDay.now().minute,
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              "Create Staff Shift",
              style: TextStyle(fontFamily: "Poppins", fontWeight: FontWeight.w600),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Staff selection
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Select Staff",
                      prefixIcon: const Icon(Icons.person),
                      border: const OutlineInputBorder(),
                    ),
                    items: staffList.map((staff) {
                      return DropdownMenuItem<String>(
                        value: staff['id'] as String?,
                        child: Text(
                          staff['username'] ?? staff['email'] ?? 'Unknown',
                          style: const TextStyle(fontFamily: "Poppins"),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedStaffId = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date selection
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text(
                      "Date",
                      style: TextStyle(fontFamily: "Poppins"),
                    ),
                    subtitle: Text(
                      DateFormat('yyyy-MM-dd').format(selectedDate),
                      style: const TextStyle(fontFamily: "Poppins"),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null && context.mounted) {
                        setState(() => selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Start time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: const Text(
                      "Start Time",
                      style: TextStyle(fontFamily: "Poppins"),
                    ),
                    subtitle: Text(
                      startTime.format(context),
                      style: const TextStyle(fontFamily: "Poppins"),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (time != null && context.mounted) {
                        setState(() => startTime = time);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // End time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: const Text(
                      "End Time",
                      style: TextStyle(fontFamily: "Poppins"),
                    ),
                    subtitle: Text(
                      endTime.format(context),
                      style: const TextStyle(fontFamily: "Poppins"),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (time != null && context.mounted) {
                        setState(() => endTime = time);
                      }
                    },
                  ),
                ],
              ),
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
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                onPressed: selectedStaffId == null
                    ? null
                    : () async {
                        final startDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          startTime.hour,
                          startTime.minute,
                        );
                        final endDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          endTime.hour,
                          endTime.minute,
                        );

                        if (endDateTime.isBefore(startDateTime) ||
                            endDateTime.isAtSameMomentAs(startDateTime)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("End time must be after start time"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final newShift = {
                          'staffId': selectedStaffId,
                          'startTime': startDateTime,
                          'endTime': endDateTime,
                        };

                        if (_hasConflict(newShift, null)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Conflict detected! This staff member already has a shift during this time."),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        try {
                          await _firestore.collection('shifts').add({
                            'staffId': selectedStaffId,
                            'startTime': Timestamp.fromDate(startDateTime),
                            'endTime': Timestamp.fromDate(endDateTime),
                            'createdAt': FieldValue.serverTimestamp(),
                            'createdBy': _auth.currentUser!.uid,
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            _fetchShifts();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Shift created successfully"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error: ${e.toString()}"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: const Text(
                  "Create",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeekView() {
    final weekDates = _getWeekDates(currentDate);
    final weekStart = weekDates.first;
    final weekEnd = weekDates.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  currentDate = currentDate.subtract(const Duration(days: 7));
                });
              },
            ),
            Text(
              "${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d, yyyy').format(weekEnd)}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: "Poppins",
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  currentDate = currentDate.add(const Duration(days: 7));
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Week grid
        Expanded(
          child: Row(
            children: weekDates.map((date) {
              final dateKey = DateFormat('yyyy-MM-dd').format(date);
              final dayShifts = shiftsByDate[dateKey] ?? [];
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday ? accent : Colors.grey[300]!,
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isToday ? accent.withOpacity(0.1) : Colors.grey[100],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              DateFormat('EEE').format(date),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isToday ? accent : Colors.black87,
                                fontFamily: "Poppins",
                              ),
                            ),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isToday ? accent : Colors.black87,
                                fontFamily: "Poppins",
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(4),
                          itemCount: dayShifts.length,
                          itemBuilder: (context, index) {
                            final shift = dayShifts[index];
                            final start = shift['startTime'] as DateTime;
                            final end = shift['endTime'] as DateTime;
                            final staffId = shift['staffId'] as String;
                            final staff = staffList.firstWhere(
                              (s) => s['id'] == staffId,
                              orElse: () => {'username': 'Unknown'},
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: accent.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    staff['username'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      fontFamily: "Poppins",
                                    ),
                                  ),
                                  Text(
                                    "${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                      fontFamily: "Poppins",
                                    ),
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
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthView() {
    final monthDates = _getMonthDates(currentDate);
    final monthName = DateFormat('MMMM yyyy').format(currentDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  currentDate = DateTime(currentDate.year, currentDate.month - 1, 1);
                });
              },
            ),
            Text(
              monthName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: "Poppins",
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Month grid header
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: "Poppins",
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Month grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
            ),
            itemCount: monthDates.length,
            itemBuilder: (context, index) {
              final date = monthDates[index];
              final dateKey = DateFormat('yyyy-MM-dd').format(date);
              final dayShifts = shiftsByDate[dateKey] ?? [];
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final isCurrentMonth = date.month == currentDate.month;

              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isToday ? accent : Colors.grey[300]!,
                    width: isToday ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isToday ? accent.withOpacity(0.1) : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentMonth
                              ? (isToday ? accent : Colors.black87)
                              : Colors.grey,
                          fontFamily: "Poppins",
                        ),
                      ),
                    ),
                    Expanded(
                      child: dayShifts.isEmpty
                          ? const SizedBox()
                          : ListView.builder(
                              padding: const EdgeInsets.all(2),
                              itemCount: dayShifts.length > 3 ? 3 : dayShifts.length,
                              itemBuilder: (context, idx) {
                                final shift = dayShifts[idx];
                                final staffId = shift['staffId'] as String;
                                final staff = staffList.firstWhere(
                                  (s) => s['id'] == staffId,
                                  orElse: () => {'username': 'Unknown'},
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    staff['username'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontFamily: "Poppins",
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                    ),
                    if (dayShifts.length > 3)
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text(
                          "+${dayShifts.length - 3} more",
                          style: TextStyle(
                            fontSize: 8,
                            color: accent,
                            fontFamily: "Poppins",
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Staff Scheduling',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC2868B),
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Row(
                              children: [
                                // View mode toggle
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildViewModeButton('week', 'Week'),
                                      _buildViewModeButton('month', 'Month'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Create shift button
                                ElevatedButton.icon(
                                  onPressed: _showCreateShiftDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text(
                                    "Create Shift",
                                    style: TextStyle(fontFamily: "Poppins"),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Calendar view
                        Expanded(
                          child: viewMode == 'week'
                              ? _buildWeekView()
                              : _buildMonthView(),
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

  Widget _buildViewModeButton(String mode, String label) {
    final isSelected = viewMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          viewMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontFamily: "Poppins",
          ),
        ),
      ),
    );
  }
}


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StaffScheduleScreen extends StatefulWidget {
  const StaffScheduleScreen({Key? key}) : super(key: key);

  @override
  _StaffScheduleScreenState createState() => _StaffScheduleScreenState();
}

class _StaffScheduleScreenState extends State<StaffScheduleScreen> {
  static const Color accent = Color(0xFFC2868B);
  static const Color lightPink = Color(0xFFFADADD);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // View mode: 'week' or 'month'
  String viewMode = 'week';

  // Current date for navigation
  DateTime currentDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final staffId = _auth.currentUser?.uid;

    if (staffId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: accent),
          title: Image.asset('assets/images/logo2.png', height: 40),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'Please log in to view your schedule',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: accent),
        title: Image.asset('assets/images/logo2.png', height: 40),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: accent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Schedule',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontFamily: 'Poppins',
                  ),
                ),
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
              ],
            ),
          ),

          // Calendar view
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('shifts')
                  .where('staffId', isEqualTo: staffId)
                  .orderBy('startTime')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: accent),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Text(
                      'No schedule data available',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                  );
                }

                final shifts = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    'startTime': (data['startTime'] as Timestamp).toDate(),
                    'endTime': (data['endTime'] as Timestamp).toDate(),
                  };
                }).toList();

                return viewMode == 'week'
                    ? _buildWeekView(shifts)
                    : _buildMonthView(shifts);
              },
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
    for (var d = startOfWeek;
        d.isBefore(endOfWeek.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))) {
      dates.add(d);
    }
    return dates;
  }

  List<Map<String, dynamic>> _getShiftsForDate(
      List<Map<String, dynamic>> allShifts, DateTime date) {
    return allShifts.where((shift) {
      final start = shift['startTime'] as DateTime;
      return start.year == date.year &&
          start.month == date.month &&
          start.day == date.day;
    }).toList();
  }

  Widget _buildWeekView(List<Map<String, dynamic>> shifts) {
    final weekDates = _getWeekDates(currentDate);
    final weekStart = weekDates.first;
    final weekEnd = weekDates.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
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
        ),
        const SizedBox(height: 16),

        // Week list - row by row
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: weekDates.length,
            itemBuilder: (context, index) {
              final date = weekDates[index];
              final dayShifts = _getShiftsForDate(shifts, date);
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isToday ? accent : Colors.grey[300]!,
                    width: isToday ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isToday ? accent.withOpacity(0.1) : Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isToday ? accent : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DateFormat('EEE').format(date).toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isToday ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontFamily: "Poppins",
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('MMMM d, yyyy').format(date),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isToday ? accent : Colors.black87,
                              fontFamily: "Poppins",
                            ),
                          ),
                          if (isToday) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: "Poppins",
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Shifts list
                    if (dayShifts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No shifts scheduled',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontFamily: "Poppins",
                            ),
                          ),
                        ),
                      )
                    else
                      ...dayShifts.map((shift) {
                        final start = shift['startTime'] as DateTime;
                        final end = shift['endTime'] as DateTime;

                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accent.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Time icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.access_time,
                                  color: accent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Time range
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        fontFamily: "Poppins",
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getDuration(start, end),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontFamily: "Poppins",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthView(List<Map<String, dynamic>> shifts) {
    final monthDates = _getMonthDates(currentDate);
    final monthName = DateFormat('MMMM yyyy').format(currentDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
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
        ),
        const SizedBox(height: 16),

        // Month grid header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
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
        ),
        const SizedBox(height: 8),

        // Month grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.2,
              ),
              itemCount: monthDates.length,
              itemBuilder: (context, index) {
                final date = monthDates[index];
                final dayShifts = _getShiftsForDate(shifts, date);
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
                final isCurrentMonth = date.month == currentDate.month;

                return InkWell(
                  onTap: dayShifts.isNotEmpty
                      ? () => _showDayShiftsDialog(date, dayShifts)
                      : null,
                  child: Container(
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
                                itemCount: dayShifts.length > 2 ? 2 : dayShifts.length,
                                itemBuilder: (context, idx) {
                                  final shift = dayShifts[idx];
                                  final start = shift['startTime'] as DateTime;
                                  final end = shift['endTime'] as DateTime;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "${DateFormat('HH:mm').format(start)}-${DateFormat('HH:mm').format(end)}",
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: "Poppins",
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        ),
                        if (dayShifts.length > 2)
                        Padding(
                          padding: const EdgeInsets.all(2),
                          child: InkWell(
                            onTap: () {
                              _showDayShiftsDialog(date, dayShifts);
                            },
                            child: Text(
                              "+${dayShifts.length - 2} more",
                              style: TextStyle(
                                fontSize: 9,
                                color: accent,
                                fontWeight: FontWeight.w600,
                                fontFamily: "Poppins",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _getDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '$hours h $minutes m';
    } else if (hours > 0) {
      return '$hours h';
    } else {
      return '$minutes m';
    }
  }

  void _showDayShiftsDialog(DateTime date, List<Map<String, dynamic>> shifts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calendar_today, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormat('yyyy-MM-dd').format(date), // ✅ DATE ONLY
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: shifts.isEmpty
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No shifts scheduled',
                style: TextStyle(fontFamily: "Poppins"),
              ),
            ),
          )
              : ListView.separated(
            shrinkWrap: true,
            itemCount: shifts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final shift = shifts[index];
              final start = shift['startTime'] as DateTime;
              final end = shift['endTime'] as DateTime;

              final dateLabel =
              DateFormat('yyyy-MM-dd').format(start); // ✅ DATE ONLY
              final timeLabel =
                  "${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}";

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accent.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.access_time,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              fontFamily: "Poppins",
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getDuration(start, end),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontFamily: "Poppins",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style: TextStyle(fontFamily: "Poppins"),
            ),
          ),
        ],
      ),
    );
  }
}


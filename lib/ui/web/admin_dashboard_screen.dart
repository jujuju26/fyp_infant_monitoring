import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fyp_infant_monitoring/ui/web/admin_packages_screen.dart';
import 'package:intl/intl.dart';
import 'admin_inventory_screen.dart';
import 'admin_logout_screen.dart';
import 'admin_meal_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_report_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_scheduling_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Data holders
  double totalSales = 0;
  double totalProfit = 0;
  int newCustomers = 0;
  int repeatedCustomers = 0;
  List<BookingData> allBookings = [];
  List<YearlySales> yearlySales = [];
  String adminName = "";
  String adminRole = "";

  bool isLoading = true;

  // Filters for Business KPI card
  final List<String> _monthOptions = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final List<String> _yearOptions =
  List.generate(11, (i) => (2015 + i).toString()); // 2015–2025

  late String _selectedMonth;
  late String _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateFormat('MMM').format(now); // e.g. "Dec"
    if (!_monthOptions.contains(_selectedMonth)) {
      // In case locale uses different short month, fallback
      _selectedMonth = _monthOptions[now.month - 1];
    }
    _selectedYear = now.year.toString();

    _loadAdminInfo();
    _loadDashboardData();
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
      print('Error signing out: $e');
    }
  }

  Future<void> _loadAdminInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final doc =
      await FirebaseFirestore.instance.collection('admin').doc(uid).get();

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

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final parentsSnapshot = await _firestore.collection('parent').get();

      if (!mounted) return;

      int newCustCount = 0;
      int repeatedCustCount = 0;

      double salesSum = 0;
      double profitSum = 0;

      List<BookingData> bookingsList = [];
      Map<int, double> salesByYear = {};

      for (final parentDoc in parentsSnapshot.docs) {
        final bookingsSnapshot =
        await parentDoc.reference.collection('bookings').get();

        if (!mounted) return;

        if (bookingsSnapshot.docs.isEmpty) {
          // No bookings, count as new customer
          newCustCount++;
          continue;
        }

        // New vs repeated customer
        bool isNewCustomer = bookingsSnapshot.docs.length == 1;
        if (isNewCustomer) {
          newCustCount++;
        } else {
          repeatedCustCount++;
        }

        for (final bookingDoc in bookingsSnapshot.docs) {
          final booking = bookingDoc.data();
          final status = (booking['status'] ?? 'PENDING') as String;

          // Safely extract totalPayable and ensure it's a double
          double totalPayable = (booking['totalPayable'] ?? 0).toDouble();

          // Revenue & profit only for APPROVED bookings
          if (status == 'APPROVED') {
            salesSum += totalPayable;
            profitSum += totalPayable * 0.3;

            // Extract the date and categorize sales by year using timestamp
            Timestamp? ts = booking['timestamp'];
            DateTime? date = ts?.toDate();

            if (date != null) {
              int year = date.year;
              salesByYear[year] = (salesByYear[year] ?? 0) + totalPayable;
            }
          }

          // Add the booking to the list for further processing
          bookingsList.add(
            BookingData(
              parentId: parentDoc.id,
              checkInDate: booking['checkInDate'],
              totalPayable: totalPayable,
              status: status,
            ),
          );
        }
      }

      List<YearlySales> yearlySalesList = [];

      for (int year = 2015; year <= 2025; year++) {
        yearlySalesList.add(
          YearlySales(
            year: year,
            sales: salesByYear[year] ?? 0,
            profit: (salesByYear[year] ?? 0) * 0.3,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        totalSales = salesSum;
        totalProfit = profitSum;
        newCustomers = newCustCount;
        repeatedCustomers = repeatedCustCount;
        allBookings = bookingsList;
        yearlySales = yearlySalesList;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load dashboard data')),
      );
    }
  }

  // Formatters
  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'en_MY', symbol: 'RM ').format(amount);

  String _formatDate(String isoDate) {
    try {
      DateTime dt = DateTime.parse(isoDate);
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  int _monthNameToNumber(String monthName) {
    final index = _monthOptions.indexOf(monthName);
    if (index == -1) return 1;
    return index + 1;
  }

  // Build charts and widgets
  Widget _buildRevenueChart() {
    // SALES
    final salesSpots = List.generate(12, (monthIndex) {
      double monthlySales = 0;

      for (final booking in allBookings) {
        if (booking.checkInDate == null) continue;
        final bookingDate = DateTime.tryParse(booking.checkInDate!);
        if (bookingDate == null) continue;

        if (bookingDate.month == monthIndex + 1 &&
            booking.status == 'APPROVED') {
          monthlySales += booking.totalPayable;
        }
      }

      // Round to 2 decimal places
      monthlySales = double.parse(monthlySales.toStringAsFixed(2));

      return FlSpot((monthIndex + 1).toDouble(), monthlySales);
    });

    // PROFIT
    final profitSpots = List.generate(12, (monthIndex) {
      double monthlyProfit = 0;

      for (final booking in allBookings) {
        if (booking.checkInDate == null) continue;
        final bookingDate = DateTime.tryParse(booking.checkInDate!);
        if (bookingDate == null) continue;

        if (bookingDate.month == monthIndex + 1 &&
            booking.status == 'APPROVED') {
          monthlyProfit += booking.totalPayable * 0.3;
        }
      }

      // Round to 2 decimals
      monthlyProfit = double.parse(monthlyProfit.toStringAsFixed(2));

      return FlSpot((monthIndex + 1).toDouble(), monthlyProfit);
    });

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          lineTouchData: LineTouchData(enabled: true),
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, _) {
                  int month = value.toInt();
                  if (month < 1 || month > 12) return const SizedBox();
                  return Text(
                    DateFormat('MMM').format(DateTime(0, month)),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25000,
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: salesSpots,
              isCurved: true,
              color: Colors.redAccent.shade200,
              barWidth: 4,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.redAccent.shade100.withOpacity(0.3),
              ),
            ),
            LineChartBarData(
              spots: profitSpots,
              isCurved: true,
              color: Colors.purpleAccent.shade100,
              barWidth: 4,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.purpleAccent.shade100.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDonutChart() {
    final total = newCustomers + repeatedCustomers;
    // If no customers yet, just show empty state
    if (total == 0) {
      return const Center(
        child: Text(
          'No customer data yet',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Left side: Indicators for New and Repeated Customers
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _legendDot(Colors.brown.shade200),
                const SizedBox(width: 8),
                const Text('New Customers', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _legendDot(Colors.pinkAccent),
                const SizedBox(width: 8),
                const Text('Repeated', style: TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ),

        const SizedBox(width: 20),
        Flexible(
          child: SizedBox(
            height: 120,
            width: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: Colors.brown.shade200,
                    value: newCustomers.toDouble(),
                    title: '',
                    radius: 20,
                  ),
                  PieChartSectionData(
                    color: Colors.pink.shade100,
                    value: repeatedCustomers.toDouble(),
                    title: '',
                    radius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  /// NEW: Business KPI Card with Month + Year filter
  Widget _buildBusinessKpiCard() {
    if (allBookings.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: const [
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'Business Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'No booking data available yet.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    final int month = _monthNameToNumber(_selectedMonth);
    final int year = int.tryParse(_selectedYear) ?? DateTime.now().year;

    final int prevMonth = month == 1 ? 12 : month - 1;
    final int prevYear = month == 1 ? year - 1 : year;

    int currentTotal = 0;
    int lastMonthTotal = 0;

    double approvedRevenueThisMonth = 0;
    int approvedCountThisMonth = 0;

    int approvedCount = 0;
    int pendingCount = 0;
    int rejectedCount = 0;

    for (final booking in allBookings) {
      if (booking.checkInDate == null) continue;
      final dt = DateTime.tryParse(booking.checkInDate!);
      if (dt == null) continue;

      // Current month/year filter
      if (dt.year == year && dt.month == month) {
        currentTotal++;

        if (booking.status == 'APPROVED') {
          approvedCount++;
          approvedCountThisMonth++;
          approvedRevenueThisMonth += booking.totalPayable;
        } else if (booking.status == 'PENDING') {
          pendingCount++;
        } else if (booking.status == 'REJECTED') {
          rejectedCount++;
          }
      }

      // Last month for growth comparison
      if (dt.year == prevYear && dt.month == prevMonth) {
        lastMonthTotal++;
      }
    }

    String growthText;
    if (lastMonthTotal == 0 && currentTotal > 0) {
      growthText = 'New';
    } else if (lastMonthTotal == 0 && currentTotal == 0) {
      growthText = '0%';
    } else {
      final growth =
          ((currentTotal - lastMonthTotal) / lastMonthTotal) * 100.0;
      growthText = '${growth.toStringAsFixed(1)}%';
    }

    final avgRevenuePerBooking = approvedCountThisMonth > 0
        ? approvedRevenueThisMonth / approvedCountThisMonth
        : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Title + Filters row
            Row(
              children: [
                const Text(
                  'Business Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
                const Spacer(),
                // Month dropdown
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedMonth,
                    items: _monthOptions
                        .map(
                          (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMonth = value;
                      });
                    },
                    underline: const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 8),
                // Year dropdown
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedYear,
                    items: _yearOptions
                        .map(
                          (y) => DropdownMenuItem(
                        value: y,
                        child: Text(y),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedYear = value;
                      });
                    },
                    underline: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // KPI rows
            Row(
              children: [
                Expanded(
                  child: _kpiTile(
                    title: 'Total Bookings',
                    value: currentTotal.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _kpiTile(
                    title: 'Last Month',
                    value: lastMonthTotal.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _kpiTile(
                    title: 'Booking Growth',
                    value: growthText,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _kpiTile(
                    title: 'Avg Revenue / Booking',
                    value: currentTotal == 0
                        ? 'RM 0.00'
                        : _formatCurrency(avgRevenuePerBooking),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status breakdown
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Status Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip('Approved', approvedCount),
                _statusChip('Pending', pendingCount),
                _statusChip('Rejected', rejectedCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiTile({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, int count) {
    // Choose colors based on status
    Color bgColor;
    Color textColor;

    switch (label.toUpperCase()) {
      case 'APPROVED':
        bgColor = const Color(0xFFE0FFF0); // soft mint green
        textColor = const Color(0xFF1E8A4F);
        break;

      case 'PENDING':
        bgColor = const Color(0xFFFFF6D8); // soft pastel yellow
        textColor = const Color(0xFFB58B00);
        break;

      case 'REJECTED':
        bgColor = const Color(0xFFFFE6E9); // soft rose red
        textColor = const Color(0xFFD64559);
        break;

      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Poppins',
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesAnalyticsChart() {
    final salesSpots = yearlySales
        .mapIndexed((index, y) => FlSpot(index.toDouble(), y.sales))
        .toList();
    final profitSpots = yearlySales
        .mapIndexed((index, y) => FlSpot(index.toDouble(), y.profit))
        .toList();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxX: yearlySales.length.toDouble(),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final double value = spot.y;
                  return LineTooltipItem(
                    value.toStringAsFixed(2),
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index < 0 || index >= yearlySales.length) {
                    return const SizedBox();
                  }
                  return Text(
                    yearlySales[index].year.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25000,
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: salesSpots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 3,
              dotData: FlDotData(show: true),
            ),
            LineChartBarData(
              spots: profitSpots,
              isCurved: true,
              color: Colors.teal,
              barWidth: 3,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  // Widget helpers
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
            backgroundColor: const Color(0xFFFADADD),
            child:
            const Icon(Icons.person, size: 24, color: Color(0xFFC2868B)),
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
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                adminRole.isEmpty ? "Admin" : adminRole,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontFamily: 'Poppins',
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

  Widget _buildSidebar() {
    List<Map<String, dynamic>> sidebarItems = [
      {'icon': Icons.dashboard, 'label': 'Dashboard', 'selected': true},
      {'icon': Icons.people, 'label': 'Staff', 'selected': false},
      {'icon': Icons.schedule, 'label': 'Scheduling', 'selected': false},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Packages', 'selected': false,},
      {'icon': Icons.set_meal_outlined, 'label': 'Meal', 'selected': false},
      {'icon': Icons.inventory_2_outlined, 'label': 'Inventory', 'selected': false},
      {'icon': Icons.book_online, 'label': 'Bookings', 'selected': false},
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
            leading: const Icon(
              Icons.power_settings_new,
              color: Colors.black54,
            ),
            title: const Text(
              'Logout',
              style: TextStyle(fontFamily: 'Poppins'),
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

  void _navigateTo(String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminDashboardScreen(),
          ),
        );
        break;
      case 'Staff':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminStaffScreen()),
        );
        break;
      case 'Scheduling':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminSchedulingScreen()),
        );
        break;
      case 'Packages':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminPackagesScreen()),
        );
        break;
      case 'Meal':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminMealScreen()),
        );
        break;
        case 'Inventory':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminInventoryScreen()),
        );
        break;
      case 'Bookings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminBookingsScreen()),
        );
        break;
      case 'Report':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminReportScreen()),
        );
        break;
      default:
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade200,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Revenue chart card
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Revenue',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        child: DropdownButton<String>(
                                          value: '2025',
                                          items: const [
                                            DropdownMenuItem(
                                              value: '2025',
                                              child: Text('2025'),
                                            ),
                                          ],
                                          onChanged: (_) {},
                                          underline:
                                          const SizedBox.shrink(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildRevenueChart(),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      _legendDot(
                                        Colors.redAccent.shade200,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('Sales'),
                                      const SizedBox(width: 12),
                                      _legendDot(Colors.purpleAccent),
                                      const SizedBox(width: 6),
                                      const Text('Profit'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildBusinessKpiCard(), // Full width
                          ),

                          const SizedBox(height: 20),

                          // Bottom cards: Customers, Sales Analytics
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customers card
                              Expanded(
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(16),
                                  ),
                                  elevation: 3,
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Align(
                                          alignment: Alignment.topLeft,
                                          child: Text(
                                            'Customers',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildCustomerDonutChart(),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceEvenly,
                                          children: [
                                            Column(
                                              children: [
                                                Text(
                                                  newCustomers.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight:
                                                    FontWeight.w700,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'New Customers',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors
                                                        .brown.shade200,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              children: [
                                                Text(
                                                  repeatedCustomers
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight:
                                                    FontWeight.w700,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Repeated',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors
                                                        .pink.shade200,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Sales analytics card
                              Expanded(
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(16),
                                  ),
                                  elevation: 3,
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Align(
                                          alignment: Alignment.topLeft,
                                          child: Text(
                                            'Sales Analytics',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildSalesAnalyticsChart(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
}

class BookingData {
  final String parentId;
  final String? checkInDate;
  final double totalPayable;
  final String status;

  BookingData({
    required this.parentId,
    this.checkInDate,
    required this.totalPayable,
    required this.status,
  });
}

class YearlySales {
  final int year;
  final double sales;
  final double profit;

  YearlySales({required this.year, required this.sales, required this.profit});
}

extension IterableExtensions<E> on Iterable<E> {
  List<T> mapIndexed<T>(T Function(int index, E e) f) {
    int index = 0;
    final result = <T>[];
    for (final element in this) {
      result.add(f(index, element));
      index++;
    }
    return result;
  }
}

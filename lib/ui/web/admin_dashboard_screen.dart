import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fyp_infant_monitoring/ui/web/admin_packages_screen.dart';
import 'package:intl/intl.dart';
import 'admin_logout_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_report_screen.dart';
import 'admin_staff_screen.dart';

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
  Map<String, dynamic>? featuredPackage;
  List<BookingData> allBookings = [];
  List<YearlySales> yearlySales = [];
  String adminName = "";
  String adminRole = "";

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
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

      final doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .get();

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
      final packageSnapshot = await _firestore.collection('package').get();

      if (!mounted) return;

      List<Map<String, dynamic>> packages = packageSnapshot.docs
          .map((doc) => doc.data())
          .toList();

      packages.sort((a, b) {
        final p1 = (a['price'] ?? 0).toDouble();
        final p2 = (b['price'] ?? 0).toDouble();
        return p2.compareTo(p1);
      });

      featuredPackage = packages.isNotEmpty ? packages.first : null;

      final parentsSnapshot = await _firestore.collection('parent').get();

      if (!mounted) return;

      int newCustCount = 0;
      int repeatedCustCount = 0;

      double salesSum = 0;
      double profitSum = 0;

      List<BookingData> bookingsList = [];
      Map<int, double> salesByYear = {};

      for (final parentDoc in parentsSnapshot.docs) {
        final bookingsSnapshot = await parentDoc.reference
            .collection('bookings')
            .get();

        if (!mounted)
          return; // Make sure widget is still mounted before proceeding.

        if (bookingsSnapshot.docs.isEmpty) {
          newCustCount++; // No bookings, so count as new customer.
          continue;
        }

        // Check if the customer has exactly one booking or more.
        bool isNewCustomer = bookingsSnapshot.docs.length == 1;
        if (isNewCustomer) {
          newCustCount++;
        } else {
          repeatedCustCount++;
        }

        for (final bookingDoc in bookingsSnapshot.docs) {
          final booking = bookingDoc.data();

          if (booking['status'] == 'APPROVED') {
            // Safely extract totalPayable and ensure it's a double
            double totalPayable = (booking['totalPayable'] ?? 0).toDouble();

            // Accumulate total sales and profit
            salesSum += totalPayable;
            profitSum += totalPayable * 0.3;

            // Extract the date and categorize sales by year
            Timestamp? ts = booking['timestamp'];
            DateTime? date = ts?.toDate();

            if (date != null) {
              int year = date.year;
              salesByYear[year] = (salesByYear[year] ?? 0) + totalPayable;
            }

            // Add the booking to the list for further processing
            bookingsList.add(
              BookingData(
                parentId: parentDoc.id,
                checkInDate: booking['checkInDate'],
                totalPayable: totalPayable,
              ),
            );
          }
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

  // Build charts and widgets
  Widget _buildRevenueChart() {
    // SALES
    final salesSpots = List.generate(12, (monthIndex) {
      double monthlySales = 0;

      for (final booking in allBookings) {
        final bookingDate = DateTime.parse(booking.checkInDate!);
        if (bookingDate.month == monthIndex + 1) {
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
        final bookingDate = DateTime.parse(booking.checkInDate!);
        if (bookingDate.month == monthIndex + 1) {
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

        // Use Flexible to prevent overflow and allow donut chart to adjust
        const SizedBox(width: 20), // Space between the legend and the donut chart
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

  Future<Widget> _buildFeaturedPackageCard() async {
    if (featuredPackage == null) {
      return const SizedBox.shrink();
    }

    final name = featuredPackage!['name'] ?? 'No Name';
    final price = (featuredPackage!['price'] ?? 0).toDouble();
    final List images = List<String>.from(featuredPackage!['images']);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6, // Higher elevation for a more distinct shadow
      shadowColor: Colors.black.withOpacity(0.2), // Softer shadow
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        // Add padding for space around the card
        child: Column(
          children: [
            // Title Text: Featured Package
            Text(
              'Featured Package', // Title text
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12), // Space between title and image
            // Display the image
            if (images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                // Round corners for the image
                child: Image.asset(
                  'assets/images/${images[0]}', // Display only the first image
                  fit: BoxFit.cover,
                  // Ensures the image covers the box without distortion
                  height: 140,
                  width: 230,
                ),
              ),
            const SizedBox(height: 7), // Space between image and text
            // Display the name of the package
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 3), // Space between name and price
            // Display the price
            Text(
              _formatCurrency(price),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 5), // Space at the bottom
          ],
        ),
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
                    "${value.toStringAsFixed(2)}", // 2 decimal places
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
                  if (index < 0 || index >= yearlySales.length)
                    return const SizedBox();
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
            backgroundColor: Color(0xFFFADADD),
            child: const Icon(Icons.person, size: 24, color: Color(0xFFC2868B)),
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
      {
        'icon': Icons.shopping_bag_outlined,
        'label': 'Packages',
        'selected': false,
      },
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
          // Use ListView.builder for sidebar items
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
                    // Perform navigation here based on the label
                    _navigateTo(item['label']);
                  },
                );
              },
            ),
          ),
          const Spacer(),
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
      onTap: () => onTap(), // Call onTap callback for navigation
    );
  }

  void _navigateTo(String label) {
    // Handle navigation based on label
    switch (label) {
      case 'Dashboard':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminDashboardScreen()),
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
          MaterialPageRoute(builder: (context) => AdminPackagesScreen()),
        );
        break;
      case 'Report':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminReportScreen()),
        );
        break;
      default:
        // Default action
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

                                // Bottom cards: Customers, Featured Package, Sales Analytics
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Customers card
                                    Expanded(
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                                              .brown
                                                              .shade200,
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
                                                              .pink
                                                              .shade200,
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

                                    const SizedBox(width: 10),

                                    // Featured package card
                                    Expanded(
                                      child: FutureBuilder(
                                        future: _buildFeaturedPackageCard(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const SizedBox(
                                              height: 150,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          }

                                          if (snapshot.hasError) {
                                            return const Text(
                                              "Error loading package",
                                              style: TextStyle(
                                                color: Colors.white,
                                              ), // Ensure text is readable on pink
                                            );
                                          }

                                          return snapshot.data ??
                                              const SizedBox.shrink(); // Display the card content
                                        },
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    // Sales analytics card
                                    Expanded(
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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

  BookingData({
    required this.parentId,
    this.checkInDate,
    required this.totalPayable,
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

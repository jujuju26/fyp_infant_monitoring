import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'admin_dashboard_screen.dart';
import 'admin_inventory_screen.dart';
import 'admin_logout_screen.dart';
import 'admin_meal_screen.dart';
import 'admin_packages_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_staff_screen.dart';

class BookingInfo {
  final String id;
  final String parentId;
  final DateTime date;
  final String packageName;
  final String customerName;
  final double totalPayable;
  final String status;

  BookingInfo({
    required this.id,
    required this.parentId,
    required this.date,
    required this.packageName,
    required this.customerName,
    required this.totalPayable,
    required this.status,
  });
}

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({Key? key}) : super(key: key);

  @override
  _AdminReportScreenState createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String adminName = '';
  String adminRole = 'Admin';

  // These are “raw overall” values (kept from original logic),
  // but the UI will now use filtered values computed in build().
  double totalRevenue = 0;
  int totalBookings = 0;

  bool _isLoading = true;

  // All bookings (raw)
  List<BookingInfo> _allBookings = [];

  // For top 3 packages (overall raw)
  Map<String, int> packageCounts = {};
  List<String> topPackages = [];

  // Filters
  String _selectedSort = 'Newest';
  String _selectedPackageFilter = 'All';
  String _selectedStatusFilter = 'All';
  List<String> _packageFilterOptions = ['All'];

  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Processing',
    'Completed',
    'Rejected',
    'Cancelled',
  ];

  // NEW: Month/Year filters
  final List<String> _monthOptions = const [
    'All',
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
  String _selectedMonth = 'All';

  List<String> _yearOptions = ['All'];
  String _selectedYear = 'All';

  @override
  void initState() {
    super.initState();
    _fetchAdminInfo();
    _fetchReportData();
  }

  // ---------------- ADMIN INFO ----------------
  Future<void> _fetchAdminInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final doc = await _firestore.collection('admin').doc(uid).get();

      if (doc.exists) {
        setState(() {
          adminName = doc.data()?['name'] ?? '';
          adminRole = doc.data()?['role'] ?? 'Admin';
        });
      }
    } catch (e) {
      debugPrint('Admin load error: $e');
    }
  }

  // -------------- FETCH REPORT DATA --------------
  Future<void> _fetchReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // All booking docs from all parents
      final bookingsSnap = await _firestore.collectionGroup('bookings').get();

      if (bookingsSnap.docs.isEmpty) {
        setState(() {
          totalBookings = 0;
          totalRevenue = 0;
          _allBookings = [];
          packageCounts = {};
          topPackages = [];
          _packageFilterOptions = ['All'];
          _yearOptions = ['All'];
          _isLoading = false;
        });
        return;
      }

      // Collect unique parentIds
      final parentIds = <String>{};
      for (final doc in bookingsSnap.docs) {
        final parentId = doc.reference.parent.parent!.id;
        parentIds.add(parentId);
      }

      // Fetch all parent docs in parallel
      final parentFutures = parentIds
          .map((id) => _firestore.collection('parent').doc(id).get())
          .toList();
      final parentSnaps = await Future.wait(parentFutures);

      // Build map parentId -> username
      final Map<String, String> parentNameMap = {};
      for (final snap in parentSnaps) {
        if (snap.exists) {
          parentNameMap[snap.id] =
              (snap.data() as Map<String, dynamic>)['username'] ?? 'Unknown';
        } else {
          parentNameMap[snap.id] = 'Unknown';
        }
      }

      double revenue = 0;
      int bookingsCount = 0;
      final Map<String, int> pkgCounts = {};
      final List<BookingInfo> bookings = [];
      final Set<int> yearSet = {};

      for (final doc in bookingsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final parentId = doc.reference.parent.parent!.id;
        final customerName = parentNameMap[parentId] ?? 'Unknown';

        // Date: prefer checkInDate, fallback to timestamp
        DateTime bookingDate = DateTime.now();
        final checkIn = data['checkInDate'];
        final ts = data['timestamp'];

        if (checkIn is Timestamp) {
          bookingDate = checkIn.toDate();
        } else if (checkIn is String) {
          bookingDate = DateTime.tryParse(checkIn) ?? bookingDate;
        } else if (ts is Timestamp) {
          bookingDate = ts.toDate();
        }

        yearSet.add(bookingDate.year);

        // First package only
        String packageName = 'Unknown';
        final packages = data['packages'];
        if (packages is List && packages.isNotEmpty) {
          final p0 = packages[0];
          if (p0 is Map<String, dynamic>) {
            packageName = p0['name'] ?? 'Unknown';
          }
        }

        // Total payable
        num totalPayableNum = data['totalPayable'] ?? 0;
        final double totalPayable = (totalPayableNum).toDouble();

        // Status
        String status = (data['status'] ?? 'pending').toString();
        final normalizedStatus = status.toLowerCase();

        // Only add revenue & count bookings if status is valid
        if (normalizedStatus == 'approved' || normalizedStatus == 'completed') {
          revenue += totalPayable;
          bookingsCount += 1;

          // Only count top packages for successful bookings
          pkgCounts[packageName] = (pkgCounts[packageName] ?? 0) + 1;
        }

        bookings.add(
          BookingInfo(
            id: doc.id,
            parentId: parentId,
            date: bookingDate,
            packageName: packageName,
            customerName: customerName,
            totalPayable: totalPayable,
            status: status,
          ),
        );
      }

      // Sort packages by count (overall)
      final sortedEntries = pkgCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Build year options from actual data
      final yearsList = yearSet.toList()..sort();
      final yearOptions =
      ['All', ...yearsList.map((y) => y.toString()).toList()];

      setState(() {
        totalRevenue = revenue;
        totalBookings = bookingsCount;
        _allBookings = bookings;
        packageCounts = pkgCounts;
        topPackages = sortedEntries.map((e) => e.key).take(5).toList();

        _packageFilterOptions = ['All', ...pkgCounts.keys];
        _yearOptions = yearOptions;

        // If previously selected year no longer exists, reset to All
        if (!_yearOptions.contains(_selectedYear)) {
          _selectedYear = 'All';
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // -------------- LOGOUT --------------
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminLogoutScreen()),
            (route) => false,
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Helper: does a booking date match current month/year filter?
  bool _matchesMonthYear(DateTime d) {
    // Year filter
    if (_selectedYear != 'All' && d.year.toString() != _selectedYear) {
      return false;
    }

    // Month filter
    if (_selectedMonth != 'All') {
      final monthLabel = DateFormat('MMM').format(d); // "Jan", "Feb", ...
      if (monthLabel != _selectedMonth) return false;
    }

    return true;
  }

  // -------------- FILTERED BOOKINGS --------------
  List<BookingInfo> get _filteredBookings {
    List<BookingInfo> list = List<BookingInfo>.from(_allBookings);

    // Apply Month/Year filters first
    list = list.where((b) => _matchesMonthYear(b.date)).toList();

    // Package filter
    if (_selectedPackageFilter != 'All') {
      list = list.where((b) => b.packageName == _selectedPackageFilter).toList();
    }

    // Status filter (using formatted version)
    if (_selectedStatusFilter != 'All') {
      list = list
          .where((b) => _formatStatus(b.status) == _selectedStatusFilter)
          .toList();
    }

    // Sort by date
    list.sort((a, b) {
      if (_selectedSort == 'Newest') {
        return b.date.compareTo(a.date);
      } else {
        return a.date.compareTo(b.date);
      }
    });

    return list;
  }

  String _formatCurrency(double amount) {
    // You can change to 'RM' if you want
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return formatter.format(amount);
  }

  String _formatDate(DateTime d) {
    return DateFormat('yyyy-MM-dd').format(d);
  }

  String _formatStatus(String raw) {
    final lower = raw.toLowerCase();
    switch (lower) {
      case 'approved':
        return 'Approved';
      case 'processing':
        return 'Processing';
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  Color _statusColorBg(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return const Color(0xFFE0FFF0);
      case 'processing':
        return const Color(0xFFEDE7FF);
      case 'pending':
        return const Color(0xFFFFF9E0);
      case 'rejected':
        return const Color(0xFFFFE5E5);
      case 'cancelled':
        return const Color(0xFFF1F1F1);
      default:
        return const Color(0xFFF1F1F1);
    }
  }

  Color _statusColorText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return const Color(0xFF1E8A4F);
      case 'processing':
        return const Color(0xFF7C4DFF);
      case 'pending':
        return const Color(0xFFB79000);
      case 'rejected':
        return const Color(0xFFD32F2F);
      case 'cancelled':
        return const Color(0xFF616161);
      default:
        return const Color(0xFF616161);
    }
  }

  // -------------- PDF EXPORT --------------
  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    final dateNow = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // Use same filtered bookings as UI
    final filtered = _filteredBookings;

    // Recompute summary based on current filters
    double revenue = 0;
    int bookingsCount = 0;
    final Map<String, int> pkgCounts = {};

    for (final b in filtered) {
      final normalized = b.status.toLowerCase();
      final isSuccess =
          normalized == 'approved' || normalized == 'completed';
      if (isSuccess) {
        revenue += b.totalPayable;
        bookingsCount += 1;
        pkgCounts[b.packageName] = (pkgCounts[b.packageName] ?? 0) + 1;
      }
    }

    final sortedEntries = pkgCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topPkgs = sortedEntries.map((e) => e.key).take(5).toList();

    final tableData = filtered
        .map((b) => [
      b.id.substring(0, 6), // short id
      _formatDate(b.date),
      b.packageName,
      b.customerName,
      _formatCurrency(b.totalPayable),
      _formatStatus(b.status),
    ])
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LullaCare Booking Report',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated on $dateNow',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  if (_selectedMonth != 'All' || _selectedYear != 'All')
                    pw.Text(
                      'Filter: '
                          '${_selectedMonth == 'All' ? '' : _selectedMonth} '
                          '${_selectedYear == 'All' ? '' : _selectedYear}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                ],
              ),
              pw.Container(
                padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(12),
                  color: PdfColors.pink100,
                ),
                child: pw.Text(
                  'Admin: ${adminName.isEmpty ? "Admin" : adminName}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(12),
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Revenue',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          )),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        _formatCurrency(revenue),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(12),
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Bookings',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          )),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '$bookingsCount',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Top packages summary
          pw.Text(
            'Top Packages',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          if (topPkgs.isEmpty)
            pw.Text('No package data for this period.')
          else
            ...topPkgs.map((pkg) {
              final count = pkgCounts[pkg] ?? 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(pkg),
                    pw.Text('$count booking${count == 1 ? '' : 's'}'),
                  ],
                ),
              );
            }),

          pw.SizedBox(height: 18),
          pw.Text(
            'Details',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: const [
              'ID',
              'Date',
              'Package',
              'Customer',
              'Price',
              'Status',
            ],
            data: tableData,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.pink300,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ---------------- UI PARTS ----------------

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
                adminName.isEmpty ? 'Loading...' : adminName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                adminRole.isEmpty ? 'Admin' : adminRole,
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
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminProfileScreen()),
                );
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    List<Map<String, dynamic>> sidebarItems = [
      {'icon': Icons.dashboard, 'label': 'Dashboard', 'selected': false},
      {'icon': Icons.people, 'label': 'Staff', 'selected': false},
      {'icon': Icons.shopping_bag_outlined, 'label': 'Packages', 'selected': false},
      {'icon': Icons.set_meal_outlined, 'label': 'Meal', 'selected': false,},
      {'icon': Icons.inventory_2_outlined, 'label': 'Inventory', 'selected': false},
      {'icon': Icons.insert_chart, 'label': 'Report', 'selected': true},
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
                  onTap: () => _navigateTo(item['label']),
                );
              },
            ),
          ),
          Divider(color: Colors.grey[300]),
          ListTile(
            leading:
            const Icon(Icons.power_settings_new, color: Colors.black54),
            title: const Text('Logout',
                style: TextStyle(fontFamily: 'Poppins')),
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
      leading: Icon(icon,
          color: selected ? Colors.red.shade200 : Colors.black54),
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
      case 'Meal':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminMealScreen()),
        );
        break;
      case 'Inventory':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminInventoryScreen()));
        break;
      case 'Report':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminReportScreen()),
        );
        break;
    }
  }

  Widget _buildStatsCard(String label, String value) {
    return Container(
      width: 220,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontFamily: 'Poppins',
              )),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPackagesCard(
      Map<String, int> filteredPackageCounts, List<String> filteredTopPackages) {
    final maxCount = filteredTopPackages.isEmpty
        ? 1
        : filteredTopPackages
        .map((p) => filteredPackageCounts[p] ?? 0)
        .fold<int>(0, (max, v) => v > max ? v : max);

    return Expanded(
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 3 Packages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 16),

            if (filteredTopPackages.isEmpty)
              const Text(
                'No package data available for this period.',
                style: TextStyle(fontSize: 14, fontFamily: 'Poppins'),
              )
            else
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: filteredTopPackages.take(3).map((pkg) {
                    final count = filteredPackageCounts[pkg] ?? 0;
                    final ratio = maxCount == 0 ? 0.0 : count / maxCount;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 5),
                        Stack(
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(0xFFF4F0F1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: ratio.clamp(0.1, 1.0),
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Color(0xFFF4A9B4),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count booking${count == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final bookings = _filteredBookings;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pink header with filters
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFFADADD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                const Spacer(),
                const Icon(Icons.filter_alt_outlined, size: 20),
                const SizedBox(width: 4),
                const Text(
                  'Filter By',
                  style: TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                ),
                const SizedBox(width: 12),

                // NEW: Month filter
                _buildSmallDropdown(
                  label: 'Month',
                  value: _selectedMonth,
                  items: _monthOptions,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedMonth = v);
                  },
                ),
                const SizedBox(width: 8),

                // NEW: Year filter
                _buildSmallDropdown(
                  label: 'Year',
                  value: _selectedYear,
                  items: _yearOptions,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedYear = v);
                  },
                ),
                const SizedBox(width: 12),

                _buildSmallDropdown(
                  label: 'Date',
                  value: _selectedSort,
                  items: const ['Newest', 'Oldest'],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedSort = v);
                  },
                ),
                const SizedBox(width: 12),
                _buildSmallDropdown(
                  label: 'Package Type',
                  value: _selectedPackageFilter,
                  items: _packageFilterOptions,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedPackageFilter = v);
                  },
                ),
                const SizedBox(width: 12),
                _buildSmallDropdown(
                  label: 'Status',
                  value: _selectedStatusFilter,
                  items: _statusOptions,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedStatusFilter = v);
                  },
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedSort = 'Newest';
                      _selectedPackageFilter = 'All';
                      _selectedStatusFilter = 'All';
                      _selectedMonth = 'All';
                      _selectedYear = 'All';
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text(
                    'Reset Filter',
                    style: TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table header
          Container(
            color: const Color(0xFFFDF7F9),
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: const [
                _TableHeaderCell('ID', flex: 2),
                _TableHeaderCell('Date', flex: 3),
                _TableHeaderCell('Package', flex: 3),
                _TableHeaderCell('Customer', flex: 3),
                _TableHeaderCell('Price', flex: 3),
                _TableHeaderCell('Status', flex: 3),
              ],
            ),
          ),

          const Divider(height: 1),

          // Table rows
          Expanded(
            child: bookings.isEmpty
                ? const Center(
              child: Text(
                'No bookings found.',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            )
                : ListView.separated(
              itemCount: bookings.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1),
              itemBuilder: (context, index) {
                final b = bookings[index];
                final statusFormatted = _formatStatus(b.status);
                return Container(
                  color: index % 2 == 0
                      ? Colors.white
                      : const Color(0xFFFDFDFD),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'BK${b.id.substring(0, 4).toUpperCase()}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _formatDate(b.date),
                          style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          b.packageName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          b.customerName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _formatCurrency(b.totalPayable),
                          style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Poppins'),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColorBg(b.status),
                              borderRadius:
                              BorderRadius.circular(16),
                            ),
                            child: Text(
                              statusFormatted,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _statusColorText(b.status),
                                fontFamily: 'Poppins',
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildSmallDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black87,
          fontFamily: 'Poppins',
        ),
        items: items
            .map(
              (e) => DropdownMenuItem<String>(
            value: e,
            child: Text(e),
          ),
        )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentPink = Color(0xFFC2868B);

    // Use filtered list to compute summary for this view
    final bookings = _filteredBookings;

    double filteredRevenue = 0;
    int filteredBookingsCount = 0;
    final Map<String, int> filteredPkgCounts = {};

    for (final b in bookings) {
      final normalized = b.status.toLowerCase();
      final isSuccess =
          normalized == 'approved' || normalized == 'completed';
      if (isSuccess) {
        filteredRevenue += b.totalPayable;
        filteredBookingsCount += 1;
        filteredPkgCounts[b.packageName] =
            (filteredPkgCounts[b.packageName] ?? 0) + 1;
      }
    }

    final sortedFilteredEntries = filteredPkgCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final filteredTopPkgs =
    sortedFilteredEntries.map((e) => e.key).take(5).toList();

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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Row
                        Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Report',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade200,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: _allBookings.isEmpty
                                  ? null
                                  : _exportPdf,
                              borderRadius:
                              BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                  BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.file_download_outlined,
                                  color: Color(0xFFC2868B),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Stats + Top Packages
                        Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                _buildStatsCard(
                                  'Total Revenue',
                                  _formatCurrency(filteredRevenue),
                                ),
                                const SizedBox(height: 16),
                                _buildStatsCard(
                                  'Total Bookings',
                                  filteredBookingsCount.toString(),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            _buildTopPackagesCard(
                                filteredPkgCounts, filteredTopPkgs),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Details Table (fixed height)
                        SizedBox(
                          height: 600,
                          child: _buildDetailsCard(),
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
}

class _TableHeaderCell extends StatelessWidget {
  final String label;
  final int flex;

  const _TableHeaderCell(this.label, {Key? key, this.flex = 3})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}

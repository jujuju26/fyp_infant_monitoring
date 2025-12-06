import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../logout_success_screen.dart';

class StaffReportScreen extends StatefulWidget {
  const StaffReportScreen({super.key});

  @override
  State<StaffReportScreen> createState() => _StaffReportScreenState();
}

class _StaffReportScreenState extends State<StaffReportScreen> {
  static const accent = Color(0xFFC2868B);
  static const lightPink = Color(0xFFFADADD);

  // Last 6 months labels (e.g. ["Jul", "Aug", "Sep", ...])
  List<String> monthsUsed = [];
  // Total crying counts per month
  List<int> cryCounts = [];
  // reasonCountsPerMonth['YYYY-MM'] = { 'hungry': x, 'discomfort': y, ... }
  Map<String, Map<String, int>> reasonCountsPerMonth = {};

  // Dropdown
  String selectedMonthKey = 'All'; // 'All' or e.g. 'December 2025'
  List<String> dropdownItems = []; // ['All', 'December 2025', ...]

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareMonthsAndLoad();
  }

  /// Prepare the last 6 months and start loading detections.
  void _prepareMonthsAndLoad() {
    final now = DateTime.now();

    // Build a list of DateTimes representing the 1st day of each of the last 6 months
    final List<DateTime> monthsDateTimes = List.generate(6, (i) {
      final monthOffset = 5 - i; // so we go oldest -> newest
      return DateTime(now.year, now.month - monthOffset, 1);
    });

    // Short labels for bar chart (Jan, Feb, ...)
    monthsUsed = monthsDateTimes.map((d) => _shortMonthLabel(d)).toList();
    cryCounts = List<int>.filled(monthsUsed.length, 0);

    // Initialize reasonCountsPerMonth map with keys 'YYYY-MM'
    reasonCountsPerMonth = {};
    for (final dt in monthsDateTimes) {
      final key = _monthKey(dt);
      reasonCountsPerMonth[key] = {
        'hungry': 0,
        'discomfort': 0,
        'tired': 0,
        'belly pain': 0,
        'burping': 0,
        'other': 0,
      };
    }

    // Dropdown items: All + every month/year (e.g. December 2025)
    dropdownItems = ['All'] +
        monthsDateTimes.map((d) => _readableMonthYear(d)).toList();

    selectedMonthKey = 'All';

    // Overall range (from oldest month start to end of current month)
    final start = monthsDateTimes.first;
    final end = DateTime(now.year, now.month + 1, 1);
    _loadDetectionsForRange(start, end);
  }

  String _shortMonthLabel(DateTime dt) {
    const labels = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return labels[dt.month - 1];
  }

  /// Key used in reasonCountsPerMonth
  String _monthKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';

  /// For dropdown display
  String _readableMonthYear(DateTime dt) {
    const long = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${long[dt.month - 1]} ${dt.year}';
  }

  Future<void> _loadDetectionsForRange(
      DateTime startInclusive, DateTime endExclusive) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final staffId = user.uid;

      // 1. Find infant(s) under this staff
      final infantsSnap = await FirebaseFirestore.instance
          .collection('staff')
          .doc(staffId)
          .collection('infants')
          .get();

      if (infantsSnap.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No infants found for this staff account.';
        });
        return;
      }

      final infantId = infantsSnap.docs.first.id;

      final detectionsSnap = await FirebaseFirestore.instance
          .collection('staff')
          .doc(staffId)
          .collection('infants')
          .doc(infantId)
          .collection('detections')
          .get();

      // Reset counts
      cryCounts = List<int>.filled(monthsUsed.length, 0);
      for (final k in reasonCountsPerMonth.keys) {
        reasonCountsPerMonth[k] = {
          'hungry': 0,
          'discomfort': 0,
          'tired': 0,
          'belly pain': 0,
          'burping': 0,
          'other': 0,
        };
      }

      // 3. Aggregate each detection
      for (final doc in detectionsSnap.docs) {
        final data = doc.data();

        // Only count if crying == true
        if (data['crying'] != true) continue;

        final int unix = data['timestamp_unix'] ?? 0;
        if (unix == 0) continue;

        // Convert unix seconds -> DateTime
        final eventTime =
        DateTime.fromMillisecondsSinceEpoch(unix * 1000);

        // Filter by chosen range
        if (eventTime.isBefore(startInclusive) ||
            eventTime.isAfter(endExclusive)) {
          continue;
        }

        // Determine which month this detection falls into
        final monthKey =
        _monthKey(DateTime(eventTime.year, eventTime.month, 1));

        final keysList = reasonCountsPerMonth.keys.toList();
        final monthIndex = keysList.indexOf(monthKey);
        if (monthIndex >= 0) {
          // Increment monthly cry count
          cryCounts[monthIndex]++;

          // Reason logic
          final causeRaw = data['reason'] ?? 'other';
          final cause = (causeRaw.toString()).toLowerCase();

          // Accepted reasons
          const allowed = ['hungry', 'discomfort', 'tired', 'belly pain', 'burping', 'other'];
          final normalized =
          allowed.contains(cause) ? cause : 'other';

          reasonCountsPerMonth[monthKey]![normalized] =
              (reasonCountsPerMonth[monthKey]![normalized] ?? 0) + 1;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading data: $e';
      });
    }
  }

  // ----------------- PDF EXPORT -----------------
  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    final totalCries =
    cryCounts.fold<int>(0, (a, b) => a + b);

    Map<String, int> reasonForPdf = {
      'hungry': 0,
      'discomfort': 0,
      'tired': 0,
      'belly pain': 0,
      'burping': 0,
      'other': 0,
    };

    if (selectedMonthKey == 'All') {
      for (final rm in reasonCountsPerMonth.values) {
        rm.forEach((k, v) {
          reasonForPdf[k] = (reasonForPdf[k] ?? 0) + v;
        });
      }
    } else {
      final index = dropdownItems.indexOf(selectedMonthKey) - 1;
      if (index >= 0 && index < reasonCountsPerMonth.length) {
        final key = reasonCountsPerMonth.keys.elementAt(index);
        reasonForPdf = Map.from(reasonCountsPerMonth[key]!);
      }
    }

    final reasonTotal =
    reasonForPdf.values.fold<int>(0, (a, b) => a + b);

    double percent(String k) =>
        reasonTotal == 0 ? 0.0 : (reasonForPdf[k]! / reasonTotal);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      "Infant Cry Analysis Report",
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFFC2868B),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      height: 2,
                      width: 200,
                      color: PdfColor.fromInt(0xFFC2868B),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 25),

              // Summary
              pw.Text(
                "Cry Summary",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFFC2868B),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(12),
                  color: PdfColor.fromInt(0xFFFADADD),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Total Cries",
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColor.fromInt(0xFFC2868B),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      "$totalCries",
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFFC2868B),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Monthly table
              pw.Text(
                "Cry Frequency by Month",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFFC2868B),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColor.fromInt(0xFFC2868B), width: 1),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFADADD),
                    ),
                    children: [
                      _pdfHeaderCell("Month"),
                      _pdfHeaderCell("Cries"),
                    ],
                  ),
                  ...List.generate(cryCounts.length, (i) {
                    return pw.TableRow(
                      children: [
                        _pdfCell(monthsUsed[i]),
                        _pdfCell("${cryCounts[i]} cries"),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 30),

              // Reason breakdown
              pw.Text(
                "Cry Reason Breakdown",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFFC2868B),
                ),
              ),
              pw.SizedBox(height: 15),
              _pdfReason("Hungry", percent('hungry')),
              pw.SizedBox(height: 12),
              _pdfReason("Discomfort", percent('discomfort')),
              pw.SizedBox(height: 12),
              _pdfReason("Tired", percent('tired')),
              pw.SizedBox(height: 12),
              _pdfReason("Belly Pain", percent('belly pain')),
              pw.SizedBox(height: 12),
              _pdfReason("Burping", percent('burping')),
              pw.SizedBox(height: 12),
              _pdfReason("Other", percent('other')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showCryDetail(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Cry Details - ${monthsUsed[index]}"),
        content: Text("Cries: ${cryCounts[index]}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _onSelectedMonthChanged(String? newVal) {
    if (newVal == null) return;
    setState(() => selectedMonthKey = newVal);
  }

  Map<String, double> _computeReasonPercentsForSelected() {
    Map<String, int> counts = {
      'hungry': 0,
      'discomfort': 0,
      'tired': 0,
      'belly pain': 0,
      'burping': 0,
      'other': 0,
    };

    if (selectedMonthKey == 'All') {
      for (final m in reasonCountsPerMonth.values) {
        m.forEach((k, v) {
          counts[k] = (counts[k] ?? 0) + v;
        });
      }
    } else {
      final index = dropdownItems.indexOf(selectedMonthKey) - 1;
      if (index >= 0 && index < reasonCountsPerMonth.length) {
        final key = reasonCountsPerMonth.keys.elementAt(index);
        counts = Map.from(reasonCountsPerMonth[key]!);
      }
    }

    final total =
    counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return {
        'hungry': 0.0,
        'discomfort': 0.0,
        'tired': 0.0,
        'belly pain': 0.0,
        'burping': 0.0,
        'other': 0.0,
      };
    }

    return counts.map((k, v) => MapEntry(k, v / total));
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    final reasonPercents = _computeReasonPercentsForSelected();

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: accent),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset('assets/images/logo2.png', height: 40),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      drawer: _buildAppDrawer(context),

      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: const [
                    Text(
                      'Infant Cry Analysis Report',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              const Text(
                'Cry Summary',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cry Frequency',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.download_outlined,
                      color: accent,
                    ),
                    onPressed: _exportPdf,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    cryCounts.fold<int>(
                        0, (a, b) => a + b)
                        .toString(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: accent,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Bar chart
                  Expanded(
                    child: SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchCallback:
                                (event, response) {
                              if (response != null &&
                                  response.spot != null &&
                                  event
                                      .isInterestedForInteractions) {
                                _showCryDetail(
                                    response.spot!
                                        .touchedBarGroupIndex);
                              }
                            },
                          ),
                          alignment:
                          BarChartAlignment.spaceAround,
                          borderData:
                          FlBorderData(show: false),
                          gridData:
                          FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget:
                                    (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 &&
                                      idx <
                                          monthsUsed
                                              .length) {
                                    return Text(
                                      monthsUsed[idx],
                                      style:
                                      const TextStyle(
                                        fontFamily:
                                        'Poppins',
                                        fontSize: 10,
                                        color: accent,
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(
                            cryCounts.length,
                                (i) => BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: cryCounts[i]
                                      .toDouble(),
                                  color: accent
                                      .withOpacity(0.3),
                                  width: 12,
                                  borderRadius:
                                  BorderRadius.circular(
                                      6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Cry reason
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cry Reason',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: lightPink,
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: selectedMonthKey,
                      underline: const SizedBox(),
                      dropdownColor: lightPink,
                      items: dropdownItems.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: accent,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: _onSelectedMonthChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _reasonBar('Hungry',
                  reasonPercents['hungry'] ?? 0.0, accent),
              const SizedBox(height: 14),
              _reasonBar(
                  'Discomfort',
                  reasonPercents['discomfort'] ?? 0.0,
                  accent),
              const SizedBox(height: 14),
              _reasonBar('Tired',
                  reasonPercents['tired'] ?? 0.0, accent),
              const SizedBox(height: 14),
              _reasonBar('Belly Pain',
                  reasonPercents['belly pain'] ?? 0.0, accent),
              const SizedBox(height: 14),
              _reasonBar('Burping',
                  reasonPercents['burping'] ?? 0.0, accent),
              const SizedBox(height: 14),
              _reasonBar('Other',
                  reasonPercents['other'] ?? 0.0, accent),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reasonBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withOpacity(0.15),
            valueColor:
            AlwaysStoppedAnimation<Color>(color.withOpacity(0.7)),
            minHeight: 12,
          ),
        ),
      ],
    );
  }
}

// ------------ PDF helper widgets ------------
pw.Widget _pdfHeaderCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromInt(0xFFC2868B),
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _pdfCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 12),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget _pdfReason(String label, double percent) {
  final barColor = PdfColor.fromInt(0xFFC2868B);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        "$label (${(percent * 100).round()}%)",
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Container(
        width: double.infinity,
        height: 10,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(5),
          color: PdfColor(194 / 255, 134 / 255, 139 / 255, 0.2),
        ),
        child: pw.Container(
          width: percent * 300,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(5),
            color: barColor,
          ),
        ),
      ),
    ],
  );
}

// ------------ Drawer ------------
Widget _buildAppDrawer(BuildContext context) {
  return Drawer(
    backgroundColor: Colors.white,
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
                    color: _StaffReportScreenState.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        ListTile(
          leading: const Icon(
            Icons.logout,
            color: _StaffReportScreenState.accent,
          ),
          title: const Text(
            'Logout',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const LogoutSuccessScreen(),
              ),
                  (route) => false,
            );
          },
        ),
      ],
    ),
  );
}

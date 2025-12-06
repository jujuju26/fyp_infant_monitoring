import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StaffDangerReportScreen extends StatefulWidget {
  const StaffDangerReportScreen({super.key});

  @override
  State<StaffDangerReportScreen> createState() => _StaffDangerReportScreen();
}

class _StaffDangerReportScreen extends State<StaffDangerReportScreen> {
  static const accent = Color(0xFFC2868B);
  static const lightPink = Color(0xFFFADADD);

  List<String> monthsUsed = [];
  List<int> dangerCounts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareMonthsAndLoad();
  }

  void _prepareMonthsAndLoad() {
    final now = DateTime.now();
    final List<DateTime> monthsDateTimes = List.generate(6, (i) {
      final monthOffset = 5 - i;
      return DateTime(now.year, now.month - monthOffset, 1);
    });

    monthsUsed = monthsDateTimes.map((d) => _shortMonthLabel(d)).toList();
    dangerCounts = List<int>.filled(monthsUsed.length, 0);

    _loadDangerData(monthsDateTimes.first,
        DateTime(now.year, now.month + 1, 1));
  }

  String _shortMonthLabel(DateTime dt) {
    const labels = [
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
      'Dec'
    ];
    return labels[dt.month - 1];
  }

  String _monthKey(DateTime dt) =>
      "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}";

  Future<void> _loadDangerData(DateTime startInclusive, DateTime endExclusive) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final staffId = user.uid;

      final infantsSnap = await FirebaseFirestore.instance
          .collection('staff')
          .doc(staffId)
          .collection('infants')
          .get();

      if (infantsSnap.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = "No infants found.";
        });
        return;
      }

      final infantId = infantsSnap.docs.first.id;

      final dangerSnap = await FirebaseFirestore.instance
          .collection('staff')
          .doc(staffId)
          .collection('infants')
          .doc(infantId)
          .collection('detections')
          .where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive))
          .where('timestamp',
          isLessThan: Timestamp.fromDate(endExclusive))
          .where('type', isEqualTo: "danger")
          .get();

      dangerCounts = List<int>.filled(monthsUsed.length, 0);

      for (final doc in dangerSnap.docs) {
        final data = doc.data();
        final ts = data["timestamp"];
        if (ts is! Timestamp) continue;

        final dt = ts.toDate();
        final index =
        monthsUsed.indexOf(_shortMonthLabel(DateTime(dt.year, dt.month, 1)));
        if (index >= 0) {
          dangerCounts[index] += 1;
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error loading data: $e";
      });
    }
  }

  // PDF Export
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final totalDangers = dangerCounts.fold<int>(0, (a, b) => a + b);
    final average = (totalDangers / dangerCounts.length).toStringAsFixed(1);
    final maxDangers = dangerCounts.isEmpty
        ? 0
        : dangerCounts.reduce((a, b) => a > b ? a : b);
    final maxMonth = dangerCounts.isEmpty
        ? "-"
        : monthsUsed[dangerCounts.indexOf(maxDangers)];

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  "Infant Danger Analysis Report",
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFFC2868B)),
                ),
              ),
              pw.SizedBox(height: 24),

              // Summary Cards
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfStatCard("Total Dangers", "$totalDangers"),
                    _pdfStatCard("Average/Month", "$average"),
                    _pdfStatCard("Max Month", "$maxMonth ($maxDangers)"),
                  ]),
              pw.SizedBox(height: 24),

              pw.Text("Monthly Danger Frequency",
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text("Month",
                            textAlign: pw.TextAlign.center)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text("Dangers",
                            textAlign: pw.TextAlign.center)),
                  ]),
                  ...List.generate(dangerCounts.length, (i) {
                    return pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(monthsUsed[i],
                              textAlign: pw.TextAlign.center)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("${dangerCounts[i]}",
                              textAlign: pw.TextAlign.center)),
                    ]);
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfStatCard(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFADADD),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ]),
    );
  }

  void _showDangerDetail(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Danger Details - ${monthsUsed[index]}"),
        content: Text("Danger Events: ${dangerCounts[index]}"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDangers = dangerCounts.fold<int>(0, (a, b) => a + b);
    final average =
    dangerCounts.isEmpty ? 0 : (totalDangers / dangerCounts.length).toStringAsFixed(1);
    final maxDangers =
    dangerCounts.isEmpty ? 0 : dangerCounts.reduce((a, b) => a > b ? a : b);
    final maxMonth =
    dangerCounts.isEmpty ? "-" : monthsUsed[dangerCounts.indexOf(maxDangers)];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: accent),
        title: SizedBox(
          width: double.infinity,
          child: Center(
            child: Column(
              children: [
                const Text(
                  "Danger Analysis Report",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFC2868B),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
          child: Text(_error!,
              style: const TextStyle(color: Colors.red)))
          : SingleChildScrollView(
        padding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statCard("Total Dangers", "$totalDangers"),
                _statCard("Average/Month", "$average"),
                _statCard("Max Month", "$maxMonth ($maxDangers)"),
              ],
            ),
            const SizedBox(height: 24),

            // Bar Chart
            Text("Monthly Danger Trend",
                style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: accent)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          "${monthsUsed[group.x.toInt()]}\n${rod.toY.toInt()} events",
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < monthsUsed.length) {
                            return Text(
                              monthsUsed[idx],
                              style: const TextStyle(
                                  color: accent,
                                  fontSize: 12,
                                  fontFamily: "Poppins"),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    dangerCounts.length,
                        (i) => BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: dangerCounts[i].toDouble(),
                          color: accent.withOpacity(0.7),
                          width: 18,
                          borderRadius: BorderRadius.circular(6))
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Detailed list
            Text("Monthly Breakdown",
                style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: accent)),
            const SizedBox(height: 12),
            ...List.generate(monthsUsed.length, (i) {
              return Card(
                color: lightPink.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(monthsUsed[i],
                      style: const TextStyle(
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w600)),
                  trailing: Text("${dangerCounts[i]} events",
                      style: const TextStyle(
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w700)),
                  onTap: () => _showDangerDetail(i),
                ),
              );
            }),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 12),
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Export PDF"),
                onPressed: _exportPdf,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lightPink.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

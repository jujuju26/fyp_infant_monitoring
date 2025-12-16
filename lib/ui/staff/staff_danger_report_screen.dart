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
  State<StaffDangerReportScreen> createState() =>
      _StaffDangerReportScreenState();
}

class _StaffDangerReportScreenState extends State<StaffDangerReportScreen> {
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

  // ------------------------------------------------------------
  // Prepare last 6 months labels + load data
  // ------------------------------------------------------------
  void _prepareMonthsAndLoad() {
    final now = DateTime.now();

    final List<DateTime> monthDates = List.generate(6, (i) {
      int offset = 5 - i;
      return DateTime(now.year, now.month - offset, 1);
    });

    monthsUsed = monthDates.map((d) => _shortMonth(d.month)).toList();
    dangerCounts = List<int>.filled(monthsUsed.length, 0);

    _loadDangerData(monthDates.first, DateTime(now.year, now.month + 1, 1));
  }

  String _shortMonth(int m) {
    const names = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return names[m - 1];
  }

  // ------------------------------------------------------------
  // LOAD FIRESTORE DATA
  // ------------------------------------------------------------
  Future<void> _loadDangerData(
      DateTime startInclusive, DateTime endExclusive) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in.");

      final staffId = user.uid;

      // Load infant assigned to staff
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

      // Convert date range → UNIX seconds
      final startUnix = startInclusive.millisecondsSinceEpoch ~/ 1000;
      final endUnix = endExclusive.millisecondsSinceEpoch ~/ 1000;

      // Query using timestamp_unix
      final dangerSnap = await FirebaseFirestore.instance
          .collection('staff')
          .doc(staffId)
          .collection('infants')
          .doc(infantId)
          .collection('detections')
          .where('timestamp_unix', isGreaterThanOrEqualTo: startUnix)
          .where('timestamp_unix', isLessThan: endUnix)
          .where('type', isEqualTo: 'danger')
          .get();

      dangerCounts = List<int>.filled(monthsUsed.length, 0);

      for (final doc in dangerSnap.docs) {
        final data = doc.data();
        final unix = data['timestamp_unix'];

        if (unix == null) continue;

        final dt = DateTime.fromMillisecondsSinceEpoch(unix * 1000);

        final monthLabel = _shortMonth(dt.month);
        final index = monthsUsed.indexOf(monthLabel);

        if (index != -1) {
          dangerCounts[index] += 1;
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error: $e";
      });
    }
  }

  // ------------------------------------------------------------
  // PDF EXPORT
  // ------------------------------------------------------------
  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    final total = dangerCounts.fold<int>(0, (a, b) => a + b);
    final avg = total / dangerCounts.length;
    final maxValue =
    dangerCounts.isEmpty ? 0 : dangerCounts.reduce((a, b) => a > b ? a : b);
    final maxMonth =
    dangerCounts.isEmpty ? "-" : monthsUsed[dangerCounts.indexOf(maxValue)];

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                  child: pw.Text("Infant Danger Analysis Report",
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFFC2868B)))),

              pw.SizedBox(height: 20),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _pdfStat("Total Dangers", total.toString()),
                  _pdfStat("Average / Month", avg.toStringAsFixed(1)),
                  _pdfStat("Highest Month", "$maxMonth ($maxValue)"),
                ],
              ),

              pw.SizedBox(height: 24),

              pw.Text("Monthly Breakdown",
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),

              pw.SizedBox(height: 12),

              pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text("Month")),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text("Dangers")),
                      ],
                    ),
                    ...List.generate(dangerCounts.length, (i) {
                      return pw.TableRow(children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(monthsUsed[i])),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text("${dangerCounts[i]}")),
                      ]);
                    })
                  ])
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _pdfStat(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFADADD),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(value,
              style:
              pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final total = dangerCounts.fold<int>(0, (a, b) => a + b);
    final double avg = total == 0 ? 0 : (total / dangerCounts.length);
    final maxValue =
    dangerCounts.isEmpty ? 0 : dangerCounts.reduce((a, b) => a > b ? a : b);
    final maxMonth =
    dangerCounts.isEmpty ? "-" : monthsUsed[dangerCounts.indexOf(maxValue)];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: accent),
        title: const Text("Danger Analysis Report",
            style: TextStyle(
                fontFamily: "Poppins",
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Text(_error!,
            style: const TextStyle(color: Colors.red)),
      )
          : _buildReportUI(total, avg, maxMonth, maxValue),
    );
  }

  Widget _buildReportUI(int total, double avg, String maxMonth, int maxValue) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Summary Row
          Row(
            children: [
              _statCard("Total Dangers", "$total"),
              _statCard("Average/Month", avg.toStringAsFixed(1)),
              _statCard("Max Month", "$maxMonth ($maxValue)"),
            ],
          ),

          const SizedBox(height: 24),

          // Bar Chart
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: List.generate(
                    dangerCounts.length,
                        (i) => BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: dangerCounts[i].toDouble(),
                          width: 18,
                          color: accent)
                    ])),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        int idx = value.toInt();
                        return Text(monthsUsed[idx],
                            style: const TextStyle(
                                fontSize: 12, color: accent));
                      },
                    ),
                  ),
                  leftTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Detailed List
          ...List.generate(monthsUsed.length, (i) {
            return Card(
              color: lightPink.withOpacity(0.3),
              child: ListTile(
                title: Text(monthsUsed[i],
                    style: const TextStyle(
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w600)),
                trailing: Text("${dangerCounts[i]} events",
                    style: const TextStyle(
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.bold)),
              ),
            );
          }),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: accent, foregroundColor: Colors.white),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("Export PDF"),
            onPressed: _exportPdf,
          )
        ],
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: lightPink.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

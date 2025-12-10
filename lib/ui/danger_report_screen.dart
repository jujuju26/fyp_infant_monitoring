import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DangerReportScreen extends StatefulWidget {
  const DangerReportScreen({super.key});

  @override
  State<DangerReportScreen> createState() => _DangerReportScreenState();
}

class _DangerReportScreenState extends State<DangerReportScreen> {
  static const accent = Color(0xFFC2868B);
  static const lightPink = Color(0xFFFADADD);

  List<DateTime> months = [];
  List<String> monthsLabel = [];
  List<int> dangerCounts = [];

  List<Map<String, dynamic>> dangerList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareMonths();
    _loadDangerData();
  }

  // -------------------------------
  // Prepare last 6 months
  // -------------------------------
  void _prepareMonths() {
    final now = DateTime.now();
    months = List.generate(6, (i) {
      final offset = 5 - i;
      return DateTime(now.year, now.month - offset, 1);
    });

    monthsLabel = months.map((d) => _shortMonth(d)).toList();
    dangerCounts = List.filled(6, 0);
  }

  String _shortMonth(DateTime d) {
    const list = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return list[d.month - 1];
  }

  // -------------------------------
  // Load danger data
  // -------------------------------
  Future<void> _loadDangerData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final infantsSnap = await FirebaseFirestore.instance
          .collection("parent")
          .doc(uid)
          .collection("infants")
          .get();

      if (infantsSnap.docs.isEmpty) {
        setState(() {
          _loading = false;
          _error = "No infant found.";
        });
        return;
      }

      final infantId = infantsSnap.docs.first.id;

      final snap = await FirebaseFirestore.instance
          .collection("parent")
          .doc(uid)
          .collection("infants")
          .doc(infantId)
          .collection("detections")
          .where("type", isEqualTo: "danger")
          .orderBy("timestamp_unix", descending: true)
          .get();

      // Full list to display
      dangerList = snap.docs.map((d) => d.data()).toList();

      // Counting per month
      dangerCounts = List.filled(6, 0);

      for (final doc in snap.docs) {
        final data = doc.data();
        final unix = data["timestamp_unix"] ?? 0;
        if (unix == 0) continue;

        final dt = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
        for (int i = 0; i < months.length; i++) {
          final m = months[i];
          if (dt.year == m.year && dt.month == m.month) {
            dangerCounts[i]++;
          }
        }
      }

      setState(() => _loading = false);

    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Error loading danger report: $e";
      });
    }
  }

  // -------------------------------
  // PDF Export
  // -------------------------------
  Future<void> _downloadPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              "Infant Danger Report",
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFFC2868B),
              ),
            ),
          ),

          pw.SizedBox(height: 20),

          pw.Text(
            "Total Danger Events: ${dangerCounts.fold(0, (a, b) => a + b)}",
            style: pw.TextStyle(fontSize: 18),
          ),

          pw.SizedBox(height: 20),

          ...dangerList.map((d) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFC2868B)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("⚠ Danger: Face Covered",
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFFD32F2F))),
                  pw.SizedBox(height: 6),
                  pw.Text("Time: ${d['timestamp_readable']}"),
                ],
              ),
            );
          })
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // -------------------------------
  // UI BUILD
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: accent),
        title: const Text(
          "Danger Report",
          style: TextStyle(
            fontFamily: "Poppins",
            color: accent,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _downloadPdf,
            icon: const Icon(Icons.picture_as_pdf, color: accent),
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accent))
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _buildContent(),
    );
  }

  // -------------------------------
  // FULL PAGE CONTENT
  // -------------------------------
  Widget _buildContent() {
    final total = dangerCounts.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Center(
            child: Text(
              "Infant Danger Summary",
              style: const TextStyle(
                fontFamily: "Poppins",
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Total Count & Graph
          const Text(
            "Total Danger Events",
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                total.toString(),
                style: const TextStyle(
                    fontFamily: "Poppins",
                    color: accent,
                    fontSize: 48,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: SizedBox(
                  height: 170,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(enabled: false),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < monthsLabel.length) {
                                  return Text(
                                    monthsLabel[index],
                                    style: const TextStyle(
                                        fontFamily: "Poppins",
                                        fontSize: 11,
                                        color: accent),
                                  );
                                }
                                return const SizedBox();
                              }),
                        ),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: List.generate(
                        dangerCounts.length,
                            (i) => BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: dangerCounts[i].toDouble(),
                            color: Colors.redAccent.withOpacity(0.6),
                            width: 12,
                            borderRadius: BorderRadius.circular(6),
                          )
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // List Title
          const Text(
            "Danger Event Details",
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 16),

          if (dangerList.isEmpty)
            const Center(
              child: Text(
                "No danger detections",
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 15,
                  color: accent,
                ),
              ),
            )
          else
            ...dangerList.map((d) => _dangerCard(d)).toList(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // -------------------------------
  // DANGER CARD
  // -------------------------------
  Widget _dangerCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
              SizedBox(width: 10),
              Text(
                "Danger: Face Covered",
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            "Detected at: ${data['timestamp_readable']}",
            style: const TextStyle(
              fontFamily: "Poppins",
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

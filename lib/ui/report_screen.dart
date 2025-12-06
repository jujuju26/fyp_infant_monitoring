import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'logout_success_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const accent = Color(0xFFC2868B);
  static const lightPink = Color(0xFFFADADD);

  List<String> monthsUsed = [];
  List<int> cryCounts = [];
  Map<String, Map<String, int>> reasonCountsPerMonth = {};

  String selectedMonthKey = "All";
  List<String> dropdownItems = [];

  bool _isLoading = true;
  String? _error;

  // -----------------------------------------------------------
  // INIT
  // -----------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _prepareMonthsAndLoad();
  }

  // -----------------------------------------------------------
  // PREPARE LAST 6 MONTHS
  // -----------------------------------------------------------
  void _prepareMonthsAndLoad() {
    final now = DateTime.now();

    final List<DateTime> monthsDT = List.generate(6, (i) {
      final offset = 5 - i;
      return DateTime(now.year, now.month - offset, 1);
    });

    monthsUsed = monthsDT.map((d) => _shortMonthLabel(d)).toList();
    cryCounts = List<int>.filled(monthsUsed.length, 0);

    // Initialize empty reason map
    for (final dt in monthsDT) {
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

    dropdownItems = ['All'] + monthsDT.map((d) => _readableMonthYear(d)).toList();

    selectedMonthKey = "All";

    final start = monthsDT.first;
    final end = DateTime(now.year, now.month + 1, 1);

    _loadDetections(start, end);
  }

  String _shortMonthLabel(DateTime dt) {
    const labels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return labels[dt.month - 1];
  }

  String _monthKey(DateTime dt) =>
      "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}";

  String _readableMonthYear(DateTime dt) {
    const full = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return "${full[dt.month - 1]} ${dt.year}";
  }

  // -----------------------------------------------------------
  // LOAD DETECTIONS (parent path)
  // -----------------------------------------------------------
  Future<void> _loadDetections(DateTime start, DateTime end) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      // Get infant
      final infantsSnap = await FirebaseFirestore.instance
          .collection("parent")
          .doc(uid)
          .collection("infants")
          .get();

      if (infantsSnap.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = "No infants found.";
        });
        return;
      }

      final infantId = infantsSnap.docs.first.id;

      final detSnap = await FirebaseFirestore.instance
          .collection("parent")
          .doc(uid)
          .collection("infants")
          .doc(infantId)
          .collection("detections")
          .get();

      // Reset counts
      cryCounts = List<int>.filled(monthsUsed.length, 0);
      reasonCountsPerMonth.updateAll((key, value) => {
        'hungry': 0,
        'discomfort': 0,
        'tired': 0,
        'belly pain': 0,
        'burping': 0,
        'other': 0,
      });

      // Aggregate detections
      for (final doc in detSnap.docs) {
        final data = doc.data();

        if (data["crying"] != true) continue;

        final int unix = data["timestamp_unix"] ?? 0;
        if (unix == 0) continue;

        final eventTime = DateTime.fromMillisecondsSinceEpoch(unix * 1000);

        if (eventTime.isBefore(start) || eventTime.isAfter(end)) continue;

        final monthKey = _monthKey(DateTime(eventTime.year, eventTime.month, 1));
        final index = reasonCountsPerMonth.keys.toList().indexOf(monthKey);
        if (index < 0) continue;

        cryCounts[index]++;

        final raw = (data["reason"] ?? "other").toString().toLowerCase();
        const allowed = ['hungry','discomfort','tired','belly pain','burping','other'];
        final normalized = allowed.contains(raw) ? raw : "other";

        reasonCountsPerMonth[monthKey]![normalized] =
            (reasonCountsPerMonth[monthKey]![normalized] ?? 0) + 1;
      }

      setState(() => _isLoading = false);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error loading report: $e";
      });
    }
  }

  // -----------------------------------------------------------
  // CALCULATE REASON PERCENTAGES
  // -----------------------------------------------------------
  Map<String, double> _computeReasonPercentsForSelected() {
    Map<String, int> counts = {
      'hungry': 0,
      'discomfort': 0,
      'tired': 0,
      'belly pain': 0,
      'burping': 0,
      'other': 0,
    };

    if (selectedMonthKey == "All") {
      for (final monthMap in reasonCountsPerMonth.values) {
        monthMap.forEach((k, v) => counts[k] = (counts[k] ?? 0) + v);
      }
    } else {
      final index = dropdownItems.indexOf(selectedMonthKey) - 1;
      if (index >= 0) {
        final key = reasonCountsPerMonth.keys.elementAt(index);
        counts = Map.from(reasonCountsPerMonth[key]!);
      }
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);

    if (total == 0) {
      return {
        'hungry': 0,
        'discomfort': 0,
        'tired': 0,
        'belly pain': 0,
        'burping': 0,
        'other': 0,
      };
    }

    return counts.map((k, v) => MapEntry(k, v / total));
  }

  // -----------------------------------------------------------
  // UI
  // -----------------------------------------------------------
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
        title: Image.asset("assets/images/logo2.png", height: 40),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      drawer: _buildDrawer(context),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _buildReportContent(reasonPercents),
    );
  }

  // -----------------------------------------------------------
  // REPORT CONTENT UI
  // -----------------------------------------------------------
  Widget _buildReportContent(Map<String, double> reasonPercents) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: const Text(
              "Infant Cry Analysis Report",
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 18,
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // --- Cry Summary ---
          const Text(
            "Cry Summary",
            style: TextStyle(
              fontSize: 16,
              color: accent,
              fontWeight: FontWeight.w600,
              fontFamily: "Poppins",
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Cry Frequency",
                style: TextStyle(
                  fontFamily: "Poppins",
                  color: accent,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined, color: accent),
                onPressed: _exportPdf,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cryCounts.fold<int>(0, (a, b) => a + b).toString(),
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
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
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < monthsUsed.length) {
                                return Text(
                                  monthsUsed[index],
                                  style: const TextStyle(
                                      fontSize: 10, color: accent, fontFamily: "Poppins"),
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
                              toY: cryCounts[i].toDouble(),
                              color: accent.withOpacity(0.3),
                              width: 12,
                              borderRadius: BorderRadius.circular(6),
                            )
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

          // ---------------- REASON SECTION ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Cry Reasons",
                style: TextStyle(
                  fontFamily: "Poppins",
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: lightPink,
                  borderRadius: BorderRadius.circular(10),
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
                          fontFamily: "Poppins",
                          fontSize: 12,
                          color: accent,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedMonthKey = v!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _reasonBar("Hungry", reasonPercents["hungry"] ?? 0),
          const SizedBox(height: 14),

          _reasonBar("Discomfort", reasonPercents["discomfort"] ?? 0),
          const SizedBox(height: 14),

          _reasonBar("Tired", reasonPercents["tired"] ?? 0),
          const SizedBox(height: 14),

          _reasonBar("Belly Pain", reasonPercents["belly pain"] ?? 0),
          const SizedBox(height: 14),

          _reasonBar("Burping", reasonPercents["burping"] ?? 0),
          const SizedBox(height: 14),

          _reasonBar("Other", reasonPercents["other"] ?? 0),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _reasonBar(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontFamily: "Poppins", fontSize: 13)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 12,
            backgroundColor: accent.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(accent.withOpacity(0.7)),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------
  // PDF EXPORT
  // -----------------------------------------------------------
  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    final totalCries = cryCounts.fold<int>(0, (a, b) => a + b);
    final reasonPercents = _computeReasonPercentsForSelected();

    Map<String, double> pdfData = reasonPercents;

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                "Infant Cry Analysis Report",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFFC2868B),
                ),
              ),
            ),
            pw.SizedBox(height: 24),

            pw.Text("Total Cries: $totalCries",
                style: pw.TextStyle(fontSize: 18)),

            pw.SizedBox(height: 24),

            pw.Text("Reason Breakdown",
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFFC2868B))),
            pw.SizedBox(height: 14),

            ...pdfData.entries.map(
                  (e) => _pdfReason(e.key, e.value),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // -----------------------------------------------------------
  // DRAWER
  // -----------------------------------------------------------
  Widget _buildDrawer(BuildContext context) {
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
                  Image.asset("assets/images/logo2.png", height: 70),
                  const SizedBox(height: 10),
                  const Text(
                    "Caring made simple",
                    style: TextStyle(
                      fontFamily: "Poppins",
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.logout, color: accent),
            title:
            const Text("Logout", style: TextStyle(fontFamily: "Poppins")),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LogoutSuccessScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// PDF Helpers
// -----------------------------------------------------------
pw.Widget _pdfReason(String label, double percent) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text("$label (${(percent * 100).round()}%)",
          style: pw.TextStyle(fontSize: 12)),
      pw.SizedBox(height: 4),
      pw.Container(
        height: 10,
        width: double.infinity,
        child: pw.Container(
          width: percent * 300,
          height: 10,
          color: PdfColor.fromInt(0xFFC2868B),
        ),
      ),
      pw.SizedBox(height: 10),
    ],
  );
}

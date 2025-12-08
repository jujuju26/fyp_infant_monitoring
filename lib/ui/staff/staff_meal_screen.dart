import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StaffMealScreen extends StatefulWidget {
  const StaffMealScreen({Key? key}) : super(key: key);

  @override
  State<StaffMealScreen> createState() => _StaffMealScreenState();
}

class _StaffMealScreenState extends State<StaffMealScreen> {
  static const Color accent = Color(0xFFC2868B);
  static const Color lightPink = Color(0xFFFADADD);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _selectedDate = DateTime.now();
  String _statusFilter = 'All'; // All / Pending / Preparing / Ready

  // ---------------------------------------------------------------------------
  // Logout (you can replace with your real logout navigation)
  // ---------------------------------------------------------------------------
  void _logout() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _formatDate(DateTime d) =>
      DateFormat('EEEE, d MMMM yyyy').format(d);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateMealStatus({
    required String docId,
    required String parentId,
    required String mealKey, // breakfast / lunch / dinner
    required String newStatus,
  }) async {
    final String dateKey = _dateKey(_selectedDate);

    try {
      await _firestore.collection('mealPlans').doc(docId).set({
        'status': {mealKey: newStatus},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final parentRef = _firestore
          .collection('parent')
          .doc(parentId)
          .collection('mealPlans')
          .doc(dateKey);

      await parentRef.set({
        'status': {mealKey: newStatus},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'READY':
        return Colors.green;
      case 'PREPARING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // =====================================================================
  //                           MAIN UI
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    final String key = _dateKey(_selectedDate);

    final query = _firestore
        .collection('mealPlans')
        .where('date', isEqualTo: key)
        .orderBy('updatedAt', descending: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),

      // ----------------------------------------------------------------------
      // Drawer
      // ----------------------------------------------------------------------
      drawer: Drawer(
        child: Container(
          color: Colors.white,
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
                title: const Text('Logout',
                    style: TextStyle(fontFamily: 'Poppins')),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),

      // ----------------------------------------------------------------------
      // AppBar
      // ----------------------------------------------------------------------
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

      // ----------------------------------------------------------------------
      // Body
      // ----------------------------------------------------------------------
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildDateAndFilterRow(),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: accent),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No meal plans for this day.',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                final filteredDocs = docs.where((doc) {
                  if (_statusFilter == 'All') return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final status =
                  (data['status'] as Map<String, dynamic>? ?? {});
                  final s1 = (status['breakfast'] ?? 'PENDING').toString();
                  final s2 = (status['lunch'] ?? 'PENDING').toString();
                  final s3 = (status['dinner'] ?? 'PENDING').toString();

                  return s1 == _statusFilter ||
                      s2 == _statusFilter ||
                      s3 == _statusFilter;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No meal plans match this filter.',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildParentMealCard(
                      docId: doc.id,
                      data: data,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //                   DATE + FILTER HEADER
  // =====================================================================
  Widget _buildDateAndFilterRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, color: accent, size: 20),
          const SizedBox(width: 8),

          // DATE TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meals for',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          TextButton(
            onPressed: _pickDate,
            child: const Text(
              'Change',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // FILTER DROPDOWN
          DropdownButton<String>(
            value: _statusFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
              DropdownMenuItem(value: 'PREPARING', child: Text('Preparing')),
              DropdownMenuItem(value: 'READY', child: Text('Ready')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _statusFilter = val;
              });
            },
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //                     MEAL CARD FOR EACH PARENT
  // =====================================================================
  Widget _buildParentMealCard({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final meals = (data['meals'] ?? {}) as Map<String, dynamic>;
    final parentId = (data['parentId'] ?? '').toString();
    final statuses = (data['status'] ?? {}) as Map<String, dynamic>;

    final b = meals['breakfast'] ?? {};
    final l = meals['lunch'] ?? {};
    final d = meals['dinner'] ?? {};

    final bStatus = (statuses['breakfast'] ?? 'PENDING').toString();
    final lStatus = (statuses['lunch'] ?? 'PENDING').toString();
    final dStatus = (statuses['dinner'] ?? 'PENDING').toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightPink),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Parent: $parentId",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          _buildMealRow(
            label: "Breakfast",
            mealKey: "breakfast",
            mealData: b,
            currentStatus: bStatus,
            docId: docId,
            parentId: parentId,
          ),

          const Divider(height: 18),

          _buildMealRow(
            label: "Lunch",
            mealKey: "lunch",
            mealData: l,
            currentStatus: lStatus,
            docId: docId,
            parentId: parentId,
          ),

          const Divider(height: 18),

          _buildMealRow(
            label: "Dinner",
            mealKey: "dinner",
            mealData: d,
            currentStatus: dStatus,
            docId: docId,
            parentId: parentId,
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //                   SINGLE MEAL ROW (e.g. Breakfast)
  // =====================================================================
  Widget _buildMealRow({
    required String label,
    required String mealKey,
    required Map<String, dynamic> mealData,
    required String currentStatus,
    required String docId,
    required String parentId,
  }) {
    final title = mealData['title'] ?? 'Not specified';
    final notes = mealData['notes'] ?? '';
    final calories =
    mealData['calories'] is num ? (mealData['calories'] as num).toDouble() : null;

    final statusColor = _statusColor(currentStatus);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),

              if (notes.toString().trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  notes,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.black87,
                  ),
                ),
              ],

              if (calories != null) ...[
                const SizedBox(height: 3),
                Text(
                  "Estimated: ${calories.toStringAsFixed(0)} kcal",
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Status dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: DropdownButton<String>(
            value: currentStatus.toUpperCase(),
            underline: const SizedBox(),
            iconSize: 18,
            items: const [
              DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
              DropdownMenuItem(value: 'PREPARING', child: Text('Preparing')),
              DropdownMenuItem(value: 'READY', child: Text('Ready')),
            ],
            onChanged: (val) {
              if (val == null) return;
              _updateMealStatus(
                docId: docId,
                parentId: parentId,
                mealKey: mealKey,
                newStatus: val,
              );
            },
          ),
        ),
      ],
    );
  }
}

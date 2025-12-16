import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParentMilkLogScreen extends StatefulWidget {
  final String? infantId;
  final String? infantName;

  const ParentMilkLogScreen({
    super.key,
    this.infantId,
    this.infantName,
  });

  @override
  State<ParentMilkLogScreen> createState() => _ParentMilkLogScreenState();
}

class _ParentMilkLogScreenState extends State<ParentMilkLogScreen> {
  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFFADADD);
  static const lightPink = Color(0xFFF8F1F3);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightPink,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Milk Feeding Log",
          style: TextStyle(
            color: accent,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: accent),
      ),
      body: widget.infantId == null
          ? _buildSelectInfantView()
          : _buildMilkLogsView(),
    );
  }

  Widget _buildSelectInfantView() {
    final parentUid = _auth.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('parent')
          .doc(parentUid)
          .collection('infants')
          .orderBy("name", descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          );
        }

        final infants = snapshot.data!.docs;

        if (infants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.child_care_outlined,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "No Infants Found",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Add an infant first to view milk logs",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: infants.length,
          itemBuilder: (context, index) {
            final doc = infants[index];
            final data = doc.data() as Map<String, dynamic>;
            final infantId = doc.id;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: pinkSoft,
                  child: Text(
                    (data["name"] ?? "I")[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: accent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  data["name"] ?? "Unnamed Infant",
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  "Tap to view milk feeding history",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParentMilkLogScreen(
                        infantId: infantId,
                        infantName: data["name"] ?? "Infant",
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMilkLogsView() {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _fetchAllMilkLogs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          );
        }

        final allLogs = snapshot.data!;

        return Column(
          children: [
            // Infant Info Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pinkSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.local_drink,
                      color: accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.infantName ?? "Infant",
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${allLogs.length} feeding${allLogs.length != 1 ? 's' : ''} recorded",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (allLogs.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up, size: 16, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            _calculateTotalAmount(allLogs).toString(),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: accent,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            "ml total",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Logs List
            Expanded(
              child: allLogs.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      color: accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: allLogs.length,
                        itemBuilder: (context, index) {
                          return _buildLogCard(allLogs[index]);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<List<QueryDocumentSnapshot>> _fetchAllMilkLogs() async {
    final allLogs = <QueryDocumentSnapshot>[];
    
    // Get all staff members
    final staffSnapshot = await _firestore.collection('staff').get();
    
    // Query milk logs from each staff member's collection
    for (var staffDoc in staffSnapshot.docs) {
      try {
        final logsSnapshot = await _firestore
            .collection('staff')
            .doc(staffDoc.id)
            .collection('infants')
            .doc(widget.infantId)
            .collection('milkLogs')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get();
        
        allLogs.addAll(logsSnapshot.docs);
      } catch (e) {
        // Skip if collection doesn't exist or infant not found
        continue;
      }
    }
    
    // Sort by timestamp descending
    allLogs.sort((a, b) {
      final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
      final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    
    return allLogs;
  }


  int _calculateTotalAmount(List<QueryDocumentSnapshot> logs) {
    int total = 0;
    for (var log in logs) {
      final data = log.data() as Map<String, dynamic>;
      total += (data['amount'] as int? ?? 0);
    }
    return total;
  }

  Widget _buildLogCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final amount = data['amount'] ?? 0;
    final milkType = data['milkType'] ?? 'Formula';
    final notes = data['notes'] ?? '';
    final staffName = data['staffName'] ?? 'Staff';

    final dateTime = timestamp?.toDate() ?? DateTime.now();
    final timeStr = "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    final dateStr = "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    final isToday = dateTime.year == DateTime.now().year &&
        dateTime.month == DateTime.now().month &&
        dateTime.day == DateTime.now().day;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with amount and time
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withOpacity(0.1),
                  pinkSoft.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_drink,
                    color: accent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "$amount",
                            style: const TextStyle(
                              fontFamily: "Poppins",
                              fontWeight: FontWeight.w800,
                              fontSize: 32,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "ml",
                              style: TextStyle(
                                fontFamily: "Poppins",
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          milkType,
                          style: TextStyle(
                            fontFamily: "Poppins",
                            fontSize: 12,
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Today",
                          style: TextStyle(
                            fontFamily: "Poppins",
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 20),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (notes.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightPink,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pinkSoft,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 18,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notes,
                            style: TextStyle(
                              fontFamily: "Poppins",
                              fontSize: 13,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: pinkSoft.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Recorded by $staffName",
                            style: TextStyle(
                              fontFamily: "Poppins",
                              fontSize: 12,
                              color: accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: pinkSoft.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_drink_outlined,
              size: 80,
              color: accent.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Milk Logs Yet",
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Milk feeding records will appear here\nonce staff members log feedings",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}


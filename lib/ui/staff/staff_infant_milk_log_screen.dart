import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffInfantMilkLogScreen extends StatefulWidget {
  final String? infantId;
  final String? infantName;

  const StaffInfantMilkLogScreen({
    super.key,
    this.infantId,
    this.infantName,
  });

  @override
  State<StaffInfantMilkLogScreen> createState() =>
      _StaffInfantMilkLogScreenState();
}

class _StaffInfantMilkLogScreenState extends State<StaffInfantMilkLogScreen> {
  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFFADADD);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final staffUid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Milk Log",
          style: TextStyle(
            color: accent,
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: accent),
      ),
      body: widget.infantId == null
          ? _buildSelectInfantView()
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('staff')
                  .doc(staffUid)
                  .collection('infants')
                  .doc(widget.infantId)
                  .collection('milkLogs')
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  );
                }

                final logs = snapshot.data!.docs;

                return Column(
                  children: [
                    // Infant Info Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: pinkSoft,
                            child: Text(
                              (widget.infantName ?? "I")[0].toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: accent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.infantName ?? "Infant",
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "${logs.length} feeding${logs.length != 1 ? 's' : ''} recorded",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.infantId != null)
                            IconButton(
                              icon: Icon(Icons.refresh, color: accent),
                              onPressed: () {
                                // Show infant selection
                                _showInfantSelector();
                              },
                            ),
                        ],
                      ),
                    ),

                    // Logs List
                    Expanded(
                      child: logs.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () async {
                                // Refresh is handled by StreamBuilder
                              },
                              color: accent,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: logs.length,
                                itemBuilder: (context, index) {
                                  return _buildLogCard(logs[index]);
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: widget.infantId != null
          ? FloatingActionButton(
              backgroundColor: accent,
              onPressed: () => _showAddLogDialog(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSelectInfantView() {
    final staffUid = _auth.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('staff')
          .doc(staffUid)
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
                  "Add an infant first to record milk logs",
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: pinkSoft,
                  child: Text(
                    (data["name"] ?? "I")[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  data["name"] ?? "Unnamed Infant",
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  "Tap to view milk logs",
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
                      builder: (_) => StaffInfantMilkLogScreen(
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: pinkSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_drink,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$amount ml",
                        style: const TextStyle(
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: accent,
                        ),
                      ),
                      Text(
                        milkType,
                        style: TextStyle(
                          fontFamily: "Poppins",
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontFamily: "Poppins",
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: TextStyle(
                          fontFamily: "Poppins",
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  "Recorded by $staffName",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.red[300],
                  onPressed: () => _confirmDelete(doc.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_drink_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "No Milk Logs Yet",
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the + button to record a feeding",
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

  void _showInfantSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Select Infant",
          style: TextStyle(fontFamily: "Poppins"),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('staff')
                .doc(_auth.currentUser!.uid)
                .collection('infants')
                .orderBy("name", descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final infants = snapshot.data!.docs;

              return ListView.builder(
                shrinkWrap: true,
                itemCount: infants.length,
                itemBuilder: (context, index) {
                  final doc = infants[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final infantId = doc.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: pinkSoft,
                      child: Text(
                        (data["name"] ?? "I")[0].toUpperCase(),
                        style: TextStyle(color: accent),
                      ),
                    ),
                    title: Text(
                      data["name"] ?? "Unnamed Infant",
                      style: const TextStyle(fontFamily: "Poppins"),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StaffInfantMilkLogScreen(
                            infantId: infantId,
                            infantName: data["name"] ?? "Infant",
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(fontFamily: "Poppins")),
          ),
        ],
      ),
    );
  }

  void _showAddLogDialog() {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedMilkType = 'Formula';
    DateTime selectedDateTime = DateTime.now();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.local_drink, color: accent),
                const SizedBox(width: 8),
                const Text(
                  "Record Milk Feeding",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount (ml)",
                      prefixIcon: Icon(Icons.straighten),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontFamily: "Poppins"),
                  ),
                  const SizedBox(height: 16),

                  // Milk Type
                  DropdownButtonFormField<String>(
                    value: selectedMilkType,
                    decoration: const InputDecoration(
                      labelText: "Milk Type",
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: ['Formula', 'Breast Milk', 'Mixed'].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type, style: const TextStyle(fontFamily: "Poppins")),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedMilkType = value!);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date & Time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text(
                      "Date & Time",
                      style: TextStyle(fontFamily: "Poppins"),
                    ),
                    subtitle: Text(
                      "${selectedDateTime.day}/${selectedDateTime.month}/${selectedDateTime.year} ${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontFamily: "Poppins"),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        );
                        if (time != null) {
                          setDialogState(() {
                            selectedDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Notes (optional)",
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontFamily: "Poppins"),
                  ),

                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text(
                  "Cancel",
                  style: TextStyle(fontFamily: "Poppins"),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final amount = int.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please enter a valid amount"),
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);

                        try {
                          final staff = _auth.currentUser;
                          final staffDoc = await _firestore
                              .collection('staff')
                              .doc(staff!.uid)
                              .get();
                          final staffName = staffDoc.data()?['username'] ?? 'Staff';

                          await _firestore
                              .collection('staff')
                              .doc(staff.uid)
                              .collection('infants')
                              .doc(widget.infantId)
                              .collection('milkLogs')
                              .add({
                            'amount': amount,
                            'milkType': selectedMilkType,
                            'notes': notesController.text.trim(),
                            'timestamp': Timestamp.fromDate(selectedDateTime),
                            'staffId': staff.uid,
                            'staffName': staffName,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Milk log recorded successfully"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error: ${e.toString()}"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: const Text(
                  "Save",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(String logId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Delete Log",
          style: TextStyle(fontFamily: "Poppins"),
        ),
        content: const Text(
          "Are you sure you want to delete this milk log?",
          style: TextStyle(fontFamily: "Poppins"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(fontFamily: "Poppins")),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _firestore
                    .collection('staff')
                    .doc(_auth.currentUser!.uid)
                    .collection('infants')
                    .doc(widget.infantId)
                    .collection('milkLogs')
                    .doc(logId)
                    .delete();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Log deleted successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.white, fontFamily: "Poppins"),
            ),
          ),
        ],
      ),
    );
  }
}


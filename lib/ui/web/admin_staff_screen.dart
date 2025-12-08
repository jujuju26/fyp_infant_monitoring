import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminStaffScreen extends StatefulWidget {
  @override
  _AdminStaffScreenState createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String sortType = "A-Z";

  List<Map<String, dynamic>> staffList = [];

  static const accent = Color(0xFFC2868B);

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    final snap = await _firestore.collection("staff").get();
    setState(() {
      staffList = snap.docs
          .map((d) => {
        "id": d.id,
        ...d.data(),
      })
          .toList();
    });
  }

  // ────────────────────────────────────────────────────────────
  // ASSIGN INFANT DIALOG
  // ────────────────────────────────────────────────────────────
  void _openAssignInfantDialog(String staffId, String staffName) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String? selectedParentId;
        String? selectedInfantId;

        return StatefulBuilder(builder: (dialogCtx, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              "Assign Infant to $staffName",
              style: const TextStyle(fontFamily: "Poppins", fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // PARENT DROPDOWN
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection("parent").snapshots(),
                    builder: (ctx, snapParents) {
                      if (!snapParents.hasData) return const LinearProgressIndicator();

                      final parents = snapParents.data!.docs;

                      if (parents.isEmpty) {
                        return const Text("No parents found.", style: TextStyle(fontFamily: "Poppins"));
                      }

                      return DropdownButtonFormField<String>(
                        value: selectedParentId,
                        decoration: const InputDecoration(
                          labelText: "Select Parent",
                          border: OutlineInputBorder(),
                        ),
                        items: parents.map((p) {
                          final data = p.data() as Map<String, dynamic>;
                          final parentName = (data["name"] ?? data["email"] ?? "Parent").toString();
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(parentName, style: const TextStyle(fontFamily: "Poppins")),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedParentId = val;
                            selectedInfantId = null;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // INFANTS OF THAT PARENT
                  if (selectedParentId != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection("parent")
                          .doc(selectedParentId)
                          .collection("infants")
                          .snapshots(),
                      builder: (ctx, snapInfants) {
                        if (!snapInfants.hasData) return const LinearProgressIndicator();

                        final infants = snapInfants.data!.docs;

                        if (infants.isEmpty) {
                          return const Text("This parent has no infants.", style: TextStyle(fontFamily: "Poppins"));
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedInfantId,
                          decoration: const InputDecoration(
                            labelText: "Select Infant",
                            border: OutlineInputBorder(),
                          ),
                          items: infants.map((inf) {
                            final data = inf.data() as Map<String, dynamic>;
                            final infantName = (data["name"] ?? "Infant").toString();
                            return DropdownMenuItem(
                              value: inf.id,
                              child: Text(infantName, style: const TextStyle(fontFamily: "Poppins")),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setStateDialog(() => selectedInfantId = val);
                          },
                        );
                      },
                    )
                  else
                    const Text(
                      "Select a parent first to load infants.",
                      style: TextStyle(fontFamily: "Poppins", color: Colors.black54),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text("Cancel", style: TextStyle(fontFamily: "Poppins")),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                onPressed: (selectedParentId == null || selectedInfantId == null)
                    ? null
                    : () async {
                  await _assignInfantToStaff(
                    staffId: staffId,
                    staffName: staffName,
                    parentId: selectedParentId!,
                    parentInfantId: selectedInfantId!,
                  );

                  if (mounted) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Infant assigned to $staffName",
                            style: TextStyle(fontFamily: "Poppins")),
                      ),
                    );
                  }
                },
                child: const Text("Assign", style: TextStyle(fontFamily: "Poppins", color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // ASSIGN INFANT TO STAFF — WITH DUPLICATE CHECK
  // ────────────────────────────────────────────────────────────
  Future<void> _assignInfantToStaff({
    required String staffId,
    required String staffName,
    required String parentId,
    required String parentInfantId,
  }) async {
    final parentInfantRef = _firestore
        .collection("parent")
        .doc(parentId)
        .collection("infants")
        .doc(parentInfantId);

    final doc = await parentInfantRef.get();
    if (!doc.exists) throw Exception("Infant no longer exists.");

    final data = doc.data() as Map<String, dynamic>;

    final staffInfantRef =
    _firestore.collection("staff").doc(staffId).collection("infants").doc(parentInfantId);

    // ❗ PREVENT DUPLICATE ASSIGNMENT
    final exist = await staffInfantRef.get();
    if (exist.exists) {
      throw Exception("This infant is already assigned to the staff.");
    }

    await staffInfantRef.set({
      ...data,
      "parentId": parentId,
      "assignedAt": FieldValue.serverTimestamp(),
      "assignedBy": FirebaseAuth.instance.currentUser!.uid,
    });
  }

  // ────────────────────────────────────────────────────────────
  // REMOVE ASSIGNMENT
  // ────────────────────────────────────────────────────────────
  Future<void> _removeAssignment(String staffId, String infantId, String infantName) async {
    await _firestore
        .collection("staff")
        .doc(staffId)
        .collection("infants")
        .doc(infantId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Removed $infantName from staff", style: TextStyle(fontFamily: "Poppins")),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filtered = staffList
        .where((s) => s["name"].toString().toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    filtered.sort((a, b) =>
    sortType == "A-Z" ? a["name"].compareTo(b["name"]) : b["name"].compareTo(a["name"]));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Staff Management",
            style: TextStyle(fontFamily: "Poppins", color: accent)),
        elevation: 0,
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search Staff",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final staff = filtered[i];
                final staffId = staff["id"];
                final staffName = staff["name"] ?? "Unnamed Staff";

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ExpansionTile(
                    title: Text(staffName,
                        style: const TextStyle(fontFamily: "Poppins", fontWeight: FontWeight.w600)),
                    subtitle: Text(staff["email"] ?? "",
                        style: const TextStyle(fontFamily: "Poppins")),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _openAssignInfantDialog(staffId, staffName),
                      child: const Text("Assign Infant",
                          style: TextStyle(fontFamily: "Poppins", color: Colors.white)),
                    ),

                    // ────────────────────────────────────────────────────
                    // SHOW ASSIGNED INFANTS
                    // ────────────────────────────────────────────────────
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection("staff")
                            .doc(staffId)
                            .collection("infants")
                            .snapshots(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final infants = snap.data!.docs;

                          if (infants.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text("No infants assigned.",
                                  style: TextStyle(fontFamily: "Poppins")),
                            );
                          }

                          return Column(
                            children: infants.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final infantName = data["name"] ?? "Infant";

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.pink[100],
                                  child: Text(
                                    infantName[0].toUpperCase(),
                                    style: const TextStyle(color: accent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(infantName, style: const TextStyle(fontFamily: "Poppins")),
                                subtitle: Text("From Parent: ${data["parentId"]}",
                                    style: const TextStyle(fontFamily: "Poppins")),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                  onPressed: () => _removeAssignment(staffId, doc.id, infantName),
                                ),
                              );
                            }).toList(),
                          );
                        },
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
}

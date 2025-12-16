import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../logout_success_screen.dart';
import 'add_infant_screen.dart';
import 'edit_infant_details_screen.dart';
import 'infant_live_monitor_screen.dart';
import 'parent_milk_log_screen.dart';

class InfantMonitoringHome extends StatefulWidget {
  const InfantMonitoringHome({super.key});

  @override
  State<InfantMonitoringHome> createState() => _InfantMonitoringHomeState();
}

class _InfantMonitoringHomeState extends State<InfantMonitoringHome> {
  String? selectedInfantId;
  Map<String, dynamic>? selectedInfantData;

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final DateTime d = value.toDate();
      return "${d.day}/${d.month}/${d.year}";
    }
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC2868B);
    const pinkSoft = Color(0xFFFADADD);

    final String parentUid = FirebaseAuth.instance.currentUser!.uid;

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

      drawer: _AppDrawer(
        selectedInfantId: selectedInfantId,
        selectedInfantData: selectedInfantData,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parent')
            .doc(parentUid)
            .collection('infants')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final infants = snapshot.data!.docs;
          if (infants.isEmpty) {
            return const Center(
              child: Text(
                'No infants added yet',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: infants.length,
            itemBuilder: (context, i) {
              final doc = infants[i];
              final data = doc.data() as Map<String, dynamic>;
              final infantId = doc.id;

              final bool isSelected = selectedInfantId == infantId;

              return Card(
                color: isSelected ? pinkSoft.withOpacity(0.4) : Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isSelected
                      ? const BorderSide(color: accent, width: 1.5)
                      : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),

                  // 👇 When tapping an infant:
                  // 1. Mark it as selected (for Edit in drawer)
                  // 2. Navigate to live monitoring placeholder screen
                  onTap: () {
                    setState(() {
                      selectedInfantId = infantId;
                      selectedInfantData = data;
                    });

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InfantLiveMonitorScreen(
                          infantId: infantId,
                          infantData: data,
                        ),
                      ),
                    );
                  },

                  leading: CircleAvatar(
                    backgroundColor: pinkSoft,
                    child: Text(
                      (data['name'] ?? 'I')[0].toUpperCase(),
                      style: const TextStyle(
                        color: accent,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  title: Text(
                    data['name'] ?? 'Unnamed Infant',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Gender: ${data['gender'] ?? '-'}",
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                      Text(
                        "Birthdate: ${formatDate(data['birthDate'])}",
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                      Text(
                        "Height: ${data['height'] ?? '-'} cm",
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                      Text(
                        "Weight: ${data['weight'] ?? '-'} kg",
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddInfantScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final String? selectedInfantId;
  final Map<String, dynamic>? selectedInfantData;

  const _AppDrawer({
    super.key,
    required this.selectedInfantId,
    required this.selectedInfantData,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC2868B);

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
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

          // EDIT INFANT (still works using selectedInfantId/Data)
          ListTile(
            leading: const Icon(Icons.edit, color: accent),
            title: const Text('Edit Infant Details',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () {
              if (selectedInfantId == null || selectedInfantData == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please tap an infant first to edit."),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditInfantScreen(
                    infantId: selectedInfantId!,
                    infantData: selectedInfantData!,
                  ),
                ),
              );
            },
          ),

          // ADD INFANT
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: accent),
            title: const Text('Add Infant',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddInfantScreen()),
              );
            },
          ),

          // MILK LOG (View Only)
          ListTile(
            leading: const Icon(Icons.local_drink, color: accent),
            title: const Text('Milk Feeding Log',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentMilkLogScreen(
                    infantId: selectedInfantId,
                    infantName: selectedInfantData?["name"],
                  ),
                ),
              );
            },
          ),

          const Divider(),

          // LOGOUT
          ListTile(
            leading: const Icon(Icons.logout, color: accent),
            title: const Text('Logout',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const LogoutSuccessScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

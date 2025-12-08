import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../logout_success_screen.dart';
import 'staff_add_infant_screen.dart';
import 'staff_edit_infant_screen.dart';
import 'staff_notification_screen.dart';
import 'staff_infant_monitor_screen.dart'; // <-- NEW

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  String? selectedInfantId;
  Map<String, dynamic>? selectedInfantData;

  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFFADADD);

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return "${d.day}/${d.month}/${d.year}";
    }
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    final staffUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,

      // APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: accent),
        title: Column(
          children: [
            Image.asset('assets/images/logo2.png', height: 40),
            const SizedBox(height: 2),
            const Text(
              "Infant Monitoring",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: accent,
              ),
            )
          ],
        ),
      ),

      // DRAWER
      drawer: _StaffDrawer(
        selectedInfantId: selectedInfantId,
        selectedInfantData: selectedInfantData,
      ),

      // INFANT LIST
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('staff')
            .doc(staffUid)
            .collection('infants')
            .orderBy("name", descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: accent),
            );
          }

          final infants = snapshot.data!.docs;

          if (infants.isEmpty) {
            return const Center(
              child: Text(
                'No infants assigned yet',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: infants.length,
            itemBuilder: (context, i) {
              final doc = infants[i];
              final data = doc.data() as Map<String, dynamic>;
              final infantId = doc.id;

              final bool isSelected = selectedInfantId == infantId;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isSelected ? pinkSoft.withOpacity(0.45) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? accent : Colors.grey.shade300,
                    width: isSelected ? 1.6 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      offset: const Offset(0, 3),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),

                  // 👉 TAP TO OPEN LIVE MONITOR
                  onTap: () {
                    setState(() {
                      selectedInfantId = infantId;
                      selectedInfantData = data;
                    });

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaffInfantMonitorScreen(
                          infantId: infantId,
                          infantData: data,
                        ),
                      ),
                    );
                  },

                  // LEADING AVATAR
                  leading: CircleAvatar(
                    radius: 26,
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

                  // MAIN INFO
                  title: Text(
                    data["name"] ?? "Unnamed Infant",
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),

                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Gender: ${data['gender'] ?? '-'}",
                            style: const TextStyle(fontFamily: 'Poppins')),
                        Text("Birthdate: ${formatDate(data['birthDate'])}",
                            style: const TextStyle(fontFamily: 'Poppins')),
                        Text("Height: ${data['height'] ?? '-'} cm",
                            style: const TextStyle(fontFamily: 'Poppins')),
                        Text("Weight: ${data['weight'] ?? '-'} kg",
                            style: const TextStyle(fontFamily: 'Poppins')),
                      ],
                    ),
                  ),

                  // QUICK NOTIF BUTTON (per infant)
                  trailing: IconButton(
                    icon:
                    const Icon(Icons.notifications_active, color: accent),
                    iconSize: 28,
                    onPressed: () {
                      setState(() {
                        selectedInfantId = infantId;
                        selectedInfantData = data;
                      });

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StaffNotificationScreen(
                            infantId: infantId,
                            infantName: data["name"] ?? "Infant",
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),

      // ADD INFANT BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StaffAddInfantScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

//
// ───────────────────────────────────────────────────────────────
//   DRAWER
// ───────────────────────────────────────────────────────────────
//

class _StaffDrawer extends StatelessWidget {
  final String? selectedInfantId;
  final Map<String, dynamic>? selectedInfantData;

  const _StaffDrawer({
    super.key,
    required this.selectedInfantId,
    required this.selectedInfantData,
  });

  static const accent = Color(0xFFC2868B);

  @override
  Widget build(BuildContext context) {
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

          // EDIT INFANT
          ListTile(
            leading: const Icon(Icons.edit, color: accent),
            title: const Text(
              'Edit Infant Details',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            onTap: () {
              if (selectedInfantId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please tap an infant first."),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffEditInfantScreen(
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
            title: const Text(
              'Add Infant',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const StaffAddInfantScreen()),
              );
            },
          ),

          // ALL NOTIFICATIONS (for all infants – mode C)
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined,
                color: accent),
            title: const Text(
              'Notifications',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            onTap: () {
              if (selectedInfantId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Tip: tap an infant first,\n"
                        "then use the bell icon for that infant.\n"
                        "This menu can later be wired to an 'All infants' view."),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StaffNotificationScreen(
                      infantId: selectedInfantId!,
                      infantName: selectedInfantData?["name"] ?? "Infant",
                    ),
                  ),
                );
              }
            },
          ),

          const Divider(),

          // LOGOUT
          ListTile(
            leading: const Icon(Icons.logout, color: accent),
            title: const Text(
              'Logout',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
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

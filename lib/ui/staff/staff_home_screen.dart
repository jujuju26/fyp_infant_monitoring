import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logout_success_screen.dart';
import 'staff_add_infant_screen.dart';
import 'staff_edit_infant_screen.dart';
import 'staff_notification_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreen();
}

class _StaffHomeScreen extends State<StaffHomeScreen> {
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

    final String staffUid = FirebaseAuth.instance.currentUser!.uid;

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
            .collection('staff')
            .doc(staffUid)
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
              final data = infants[i].data() as Map<String, dynamic>;
              final infantId = infants[i].id;

              return Card(
                color: selectedInfantId == infantId ? pinkSoft.withOpacity(0.4) : Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: selectedInfantId == infantId
                      ? BorderSide(color: accent, width: 1.5)
                      : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),

                  // When tapping card → select infant
                  onTap: () {
                    setState(() {
                      selectedInfantId = infantId;
                      selectedInfantData = data;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${data['name']} selected"),
                        duration: Duration(seconds: 1),
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
            MaterialPageRoute(builder: (_) => const StaffAddInfantScreen()),
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

          ListTile(
            leading: const Icon(Icons.edit, color: accent),
            title: const Text('Edit Infant Details',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () {
              if (selectedInfantId == null) {
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
                  builder: (_) => StaffEditInfantScreen(
                    infantId: selectedInfantId!,
                    infantData: selectedInfantData!,
                  ),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: accent),
            title: const Text('Add Infant',
                style: TextStyle(fontFamily: 'Poppins')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffAddInfantScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: accent),
            title: const Text(
              'Notifications',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StaffNotificationScreen()),
              );
            },
          ),

          const Divider(),

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

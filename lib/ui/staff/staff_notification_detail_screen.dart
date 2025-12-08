import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffNotificationDetailScreen extends StatelessWidget {
  final String infantId;
  final String detectionId;

  const StaffNotificationDetailScreen({
    super.key,
    required this.infantId,
    required this.detectionId,
  });

  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFF8E9EC);

  @override
  Widget build(BuildContext context) {
    final staffUid = FirebaseAuth.instance.currentUser!.uid;

    final docRef = FirebaseFirestore.instance
        .collection('staff')
        .doc(staffUid)
        .collection('infants')
        .doc(infantId)
        .collection('detections')
        .doc(detectionId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
        title: const Text(
          "Alert Details",
          style: TextStyle(
            fontFamily: "Poppins",
            fontSize: 20,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) {
            return const Center(child: Text("This detection no longer exists."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final String type = (data['type'] ?? 'cry').toString();
          final String reason = (data['reason'] ?? '-').toString();
          final String timeText = (data['timestamp_readable'] ?? '-').toString();

          /// ---- CRY REASON DESCRIPTIONS ----
          final Map<String, String> reasonDescriptions = {
            "hungry": "The system detected crying patterns related to hunger.",
            "tired": "The baby may be sleepy or overtired.",
            "burping": "The baby might need to burp after feeding.",
            "belly_pain": "Crying patterns indicate discomfort or stomach pain.",
            "discomfort":
            "General discomfort detected such as heat, wet diaper, or tight clothing.",
          };

          /// ---- CRY RECOMMENDED ACTIONS ----
          final Map<String, String> recommendedActions = {
            "hungry": "• Try feeding the baby.\n• Check last feeding time.",
            "tired": "• Reduce noise & light.\n• Gently hold baby in comfortable position.",
            "burping": "• Hold baby upright.\n• Gently pat the back.",
            "belly_pain": "• Massage the belly.\n• Check for gas buildup.",
            "discomfort": "• Check diaper.\n• Adjust clothing.\n• Ensure room temperature is OK.",
          };

          /// ---- UI CONTENT THAT WE WILL BUILD ----
          String title = "";
          String description = "";
          String actions = "";
          IconData icon = Icons.child_care_rounded;
          bool isDanger = false;
          Color dangerColor = Colors.redAccent;

          // ============================================
          //        HANDLE DANGER ALERTS
          // ============================================
          if (type == "danger_face_covered") {
            isDanger = true;
            title = "Danger: Face Covered";
            description =
            "The camera detected that the baby's face is covered.\nThis is a suffocation risk.";
            actions =
            "• Immediately remove any blanket or object.\n• Ensure baby's nose and mouth are visible.\n• Check baby’s breathing.";
            icon = Icons.warning_rounded;
          } else if (type == "danger_rollover") {
            isDanger = true;
            title = "Danger: Unsafe Sleeping Position";
            description =
            "The system detected that the baby rolled into a risky sleep position.";
            actions =
            "• Place baby back on their back.\n• Remove pillows / loose items.\n• Ensure safe sleep environment.";
            icon = Icons.report_gmailerrorred_rounded;
          }

          // ============================================
          //        HANDLE REGULAR CRY REASONS
          // ============================================
          else {
            title = "Crying: ${reason.toUpperCase()}";
            description = reasonDescriptions[reason] ?? "Crying detected.";
            actions = recommendedActions[reason] ?? "No recommended actions.";
            icon = Icons.child_care_rounded;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TIME
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ICON + BACKGROUND CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: isDanger
                          ? [dangerColor.withOpacity(0.25), Colors.white]
                          : [pinkSoft, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 90,
                    color: isDanger ? dangerColor : accent,
                  ),
                ),

                const SizedBox(height: 35),

                // TITLE
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDanger ? Colors.redAccent : Colors.black87,
                  ),
                ),

                const SizedBox(height: 18),

                // DESCRIPTION
                _infoBox(description),

                const SizedBox(height: 30),

                // ACTIONS
                Text(
                  "Recommended Actions",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDanger ? Colors.redAccent : Colors.black87,
                  ),
                ),

                const SizedBox(height: 10),

                _infoBox(actions, highlight: isDanger),
              ],
            ),
          );
        },
      ),
    );
  }

  // INFO BOX WIDGET
  Widget _infoBox(String text, {bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight ? Colors.redAccent.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? Colors.redAccent : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 15,
          height: 1.6,
          color: Colors.black87,
        ),
      ),
    );
  }
}

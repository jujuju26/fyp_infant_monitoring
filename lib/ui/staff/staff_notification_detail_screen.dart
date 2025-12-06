import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                "This detection no longer exists.",
                style: TextStyle(fontFamily: "Poppins"),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final bool crying = data['crying'] ?? false;
          final String reason = (data['reason'] ?? '-').toString();
          final String timeText =
          (data['timestamp_readable'] ?? '-').toString();

          Map<String, String> reasonDescriptions = {
            "hungry": "The system detected crying patterns related to hunger.",
            "tired": "The baby may be sleepy or overtired.",
            "burping": "The baby might need to burp after feeding.",
            "belly_pain": "Crying patterns indicate discomfort or stomach pain.",
            "discomfort": "General discomfort detected such as heat, wet diaper, or tight clothing.",
          };

          Map<String, String> recommendedActions = {
            "hungry": "• Try feeding the baby.\n• Check last feeding time.\n• Observe if crying stops after feeding.",
            "tired": "• Rock the baby gently.\n• Reduce light & noise.\n• Move baby to a comfortable sleeping position.",
            "burping": "• Hold baby upright.\n• Gently pat their back.\n• Burp between feeding intervals.",
            "belly_pain": "• Massage the belly gently.\n• Check for gas buildup.\n• Ensure baby is not constipated.\n• Seek medical help if pain continues.",
            "discomfort": "• Check diaper condition.\n• Adjust clothing.\n• Ensure room temperature is comfortable.",
          };

          String title = reason.toUpperCase();
          String reasonText = reasonDescriptions[reason] ?? "No description available.";
          String actionText = recommendedActions[reason] ?? "No recommended actions.";

          bool isDanger = (reason == "belly_pain");

          IconData icon = Icons.child_care_rounded;
          if (reason == "hungry") icon = Icons.local_drink_rounded;
          if (reason == "tired") icon = Icons.bedtime_rounded;
          if (reason == "burping") icon = Icons.air_rounded;
          if (reason == "belly_pain") icon = Icons.warning_rounded;
          if (reason == "discomfort") icon = Icons.sentiment_dissatisfied_rounded;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TIME ROW
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
                const SizedBox(height: 18),

                // ICON CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 35),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: isDanger
                          ? [Colors.redAccent.withOpacity(0.25), Colors.white]
                          : [pinkSoft, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 85,
                    color: isDanger ? Colors.redAccent : accent,
                  ),
                ),

                const SizedBox(height: 35),

                // REASON TITLE
                _sectionTitle("Reason Detected"),
                _infoBox(reasonText, highlight: false),

                const SizedBox(height: 35),

                // ACTIONS
                _sectionTitle("Suggested Actions"),
                _infoBox(
                  actionText,
                  highlight: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- SECTION TITLE ---
  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 17,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- INFO BOX ---
  Widget _infoBox(
      String text, {
        required bool highlight,
        Color? highlightColor,
      }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight
            ? (highlightColor ?? accent).withOpacity(0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? (highlightColor ?? accent) : Colors.black12,
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

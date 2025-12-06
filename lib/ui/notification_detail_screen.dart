import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationDetailScreen extends StatelessWidget {
  final String detectionId;
  final String infantId;

  NotificationDetailScreen({
    super.key,
    required this.detectionId,
    required this.infantId,
  });

  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFF8E9EC);

  Map<String, String> reasonDescriptions = {
    "hungry": "The system detected crying patterns related to hunger.",
    "tired": "The baby may be sleepy or overtired.",
    "burping": "The baby might need to burp after feeding.",
    "belly_pain": "Crying patterns indicate discomfort or stomach pain.",
    "discomfort": "General discomfort was detected, possibly due to heat, wet diaper, or tight clothing.",
  };

  Map<String, String> recommendedActions = {
    "hungry": "• Try feeding the baby.\n• Check last feeding time.\n• Observe if crying stops after feeding.",
    "tired": "• Rock or gently pat the baby.\n• Reduce noise and brightness.\n• Try placing baby in a comfortable sleeping position.",
    "burping": "• Gently pat the baby's back.\n• Hold baby upright for a few minutes.\n• Burp between feeding intervals.",
    "belly_pain": "• Massage baby's belly gently.\n• Check for gas buildup.\n• Ensure baby is not constipated.\n• Consult doctor if pain persists.",
    "discomfort": "• Check diaper condition.\n• Adjust baby's clothing.\n• Make sure temperature is comfortable.\n• Remove anything irritating baby's skin.",
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("parent")
          .doc(uid)
          .collection("infants")
          .doc(infantId)
          .collection("detections")
          .doc(detectionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: accent),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final reason = data["reason"] ?? "crying";
        final timestamp = data["timestamp_readable"] ?? "--";

        final description = reasonDescriptions[reason] ??
            "The system detected a crying episode.";
        final actions = recommendedActions[reason] ??
            "• Observe the baby.\n• Ensure the environment is comfortable.";

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            centerTitle: true,
            title: Text(
              "Baby Cry Alert",
              style: const TextStyle(
                fontFamily: "Poppins",
                fontSize: 20,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ---------------- ICON CARD ----------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 35),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        pinkSoft,
                        Colors.white,
                      ],
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
                  child: const Icon(
                    Icons.child_care_rounded,
                    size: 85,
                    color: accent,
                  ),
                ),

                const SizedBox(height: 30),

                // ---------------- TIMESTAMP ----------------
                _sectionTitle("Detected At"),
                _infoBox(timestamp, highlight: false),

                const SizedBox(height: 30),

                // ---------------- REASON ----------------
                _sectionTitle("Reason Identified"),
                _infoBox(description, highlight: false),

                const SizedBox(height: 30),

                // ---------------- ACTIONS ----------------
                _sectionTitle("Recommended Actions"),
                _infoBox(actions, highlight: true, highlightColor: accent),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- TITLE ----------------
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

  // ---------------- BOX ----------------
  Widget _infoBox(String text,
      {required bool highlight, Color? highlightColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: highlight
            ? (highlightColor ?? accent).withOpacity(0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
          highlight ? (highlightColor ?? accent) : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
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

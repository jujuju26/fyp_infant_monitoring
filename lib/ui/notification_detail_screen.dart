import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationDetailScreen extends StatelessWidget {
  final String infantId;
  final String detectionId;

  const NotificationDetailScreen({
    super.key,
    required this.infantId,
    required this.detectionId,
  });

  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFFADADD);

  // Crying reason descriptions
  static const Map<String, String> reasonDescriptions = {
    "hungry": "The system detected crying patterns related to hunger.",
    "tired": "The baby may be sleepy or overtired.",
    "burping": "The baby might need to burp after feeding.",
    "belly_pain": "Crying patterns indicate discomfort or stomach pain.",
    "discomfort":
    "General discomfort detected, possibly due to heat, wet diaper, or tight clothing.",
  };

  // Recommended actions
  static const Map<String, String> recommendedActions = {
    "hungry":
    "• Try feeding the baby.\n• Check last feeding time.\n• Observe if crying stops after feeding.",
    "tired":
    "• Rock or gently pat the baby.\n• Reduce noise and brightness.\n• Place baby in a comfortable sleeping position.",
    "burping":
    "• Gently pat the baby's back.\n• Hold baby upright for a few minutes.\n• Burp during feeding intervals.",
    "belly_pain":
    "• Massage baby's belly gently.\n• Check for gas buildup.\n• Ensure baby is not constipated.\n• Consult a doctor if pain persists.",
    "discomfort":
    "• Check diaper condition.\n• Adjust baby's clothing.\n• Ensure temperature is comfortable.\n• Remove anything irritating the skin.",
  };

  // Danger descriptions
  static const Map<String, String> dangerDescriptions = {
    "face_covered":
    "The system detected that the baby's face is covered — this may block breathing.",
    "unsafe_sleep":
    "The baby is in a risky sleep position which may cause suffocation.",
    "fall_risk":
    "Baby movement suggests possible fall or rollover danger.",
  };

  // Danger action recommendations
  static const Map<String, String> dangerActions = {
    "face_covered":
    "⚠ Immediately remove any blanket, pillow, or cloth covering the baby's face.\n⚠ Ensure their airway is clear.\n• Reposition baby safely on their back.",
    "unsafe_sleep":
    "• Adjust baby to a safe face-up sleeping position.\n• Remove loose bedding.\n• Ensure crib is free of soft objects.",
    "fall_risk":
    "• Move baby away from crib edges.\n• Ensure crib rails are secured.\n• Monitor the baby closely.",
  };

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: accent),
        title: Image.asset('assets/images/logo2.png', height: 42),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection("parent")
            .doc(uid)
            .collection("infants")
            .doc(infantId)
            .collection("detections")
            .doc(detectionId)
            .get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() as Map<String, dynamic>? ?? {};

          final String type = data["type"] ?? "cry";
          final String reason = data["reason"] ?? "unknown";
          final String timestamp = data["timestamp_readable"] ?? "-";
          final String? imageUrl = data["image_url"];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(type),
                const SizedBox(height: 10),

                Text(
                  timestamp,
                  style: const TextStyle(
                    fontFamily: "Poppins",
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 20),

                if (imageUrl != null) _imagePreview(imageUrl),

                const SizedBox(height: 20),

                if (type == "cry") _cryDetails(reason),
                if (type == "danger") _dangerDetails(reason),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // HEADER BOX
  Widget _header(String type) {
    final bool isDanger = type == "danger";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDanger ? Colors.red.shade100 : pinkSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.child_care_rounded,
            size: 30,
            color: isDanger ? Colors.red : accent,
          ),
          const SizedBox(width: 12),
          Text(
            isDanger ? "Danger Detected" : "Baby is Crying",
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDanger ? Colors.red : accent,
            ),
          ),
        ],
      ),
    );
  }

  // IMAGE PREVIEW
  Widget _imagePreview(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        width: double.infinity,
        height: 260,
        fit: BoxFit.cover,
      ),
    );
  }

  // CRY DETAILS
  Widget _cryDetails(String reason) {
    final desc = reasonDescriptions[reason] ?? "Crying detected.";
    final actions = recommendedActions[reason] ?? "• Check your baby.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Reason: ${reason.replaceAll('_', ' ').toUpperCase()}",
          style: const TextStyle(
            fontFamily: "Poppins",
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        Text(desc, style: const TextStyle(fontFamily: "Poppins", fontSize: 14)),

        const SizedBox(height: 20),

        const Text(
          "Recommended Actions",
          style: TextStyle(
            fontFamily: "Poppins",
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        Text(actions,
            style: const TextStyle(fontFamily: "Poppins", fontSize: 14)),
      ],
    );
  }

  // DANGER DETAILS
  Widget _dangerDetails(String reason) {
    final desc =
        dangerDescriptions[reason] ?? "Potential danger detected. Check immediately.";
    final actions = dangerActions[reason] ??
        "⚠ Ensure the baby is safe and breathing normally.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Danger Type: ${reason.replaceAll('_', ' ').toUpperCase()}",
          style: const TextStyle(
            fontFamily: "Poppins",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),

        const SizedBox(height: 10),
        Text(desc, style: const TextStyle(fontFamily: "Poppins", fontSize: 14)),

        const SizedBox(height: 20),
        const Text(
          "Immediate Steps",
          style: TextStyle(
            fontFamily: "Poppins",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),

        const SizedBox(height: 10),
        Text(actions,
            style: const TextStyle(fontFamily: "Poppins", fontSize: 14)),
      ],
    );
  }
}

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
    "• Check diaper condition.\n• Adjust baby's clothing.\n• Ensure room temperature is comfortable.\n• Remove anything irritating the skin.",
  };

  // Only keep 1 danger type now
  static const dangerDescriptions = {
    "face_covered":
    "The system detected that the baby's face is covered — this may block breathing.",
  };

  static const dangerActions = {
    "face_covered":
    "⚠ Immediately remove any blanket, pillow, or cloth covering the baby's face.\n⚠ Ensure the airway is clear.\n• Reposition baby safely on their back.",
  };

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: accent),
        title: Image.asset('assets/images/logo2.png', height: 42),
        centerTitle: true,
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
                const SizedBox(height: 18),

                // TIMESTAMP
                _softInfoBox(Icons.access_time, "Detected at:", timestamp),

                const SizedBox(height: 20),

                if (imageUrl != null) _imagePreview(imageUrl),

                const SizedBox(height: 25),

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

  // ---------------- UI COMPONENTS ---------------- //

  Widget _header(String type) {
    final bool isDanger = type == "danger";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDanger
              ? [Colors.red.shade300, Colors.red.shade100]
              : [accent.withOpacity(0.8), pinkSoft],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            isDanger ? Icons.warning_amber_rounded : Icons.child_care_rounded,
            size: 36,
            color: Colors.white,
          ),
          const SizedBox(width: 14),
          Text(
            isDanger ? "Danger Detected" : "Baby is Crying",
            style: const TextStyle(
              fontFamily: "Poppins",
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softInfoBox(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pinkSoft.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 26),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 13,
                      color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePreview(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.network(
        url,
        width: double.infinity,
        height: 260,
        fit: BoxFit.cover,
      ),
    );
  }

  // ------------ CRY DETAILS ------------- //

  Widget _cryDetails(String reason) {
    final desc = reasonDescriptions[reason] ?? "Crying detected.";
    final actions = recommendedActions[reason] ?? "• Check your baby.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Cry Analysis"),
        _infoCard(desc),

        const SizedBox(height: 20),

        _sectionTitle("Recommended Actions"),
        _actionCard(actions),
      ],
    );
  }

  // ------------ DANGER DETAILS ------------- //

  Widget _dangerDetails(String reason) {
    final desc = dangerDescriptions[reason] ??
        "Potential danger detected. Check immediately.";
    final actions = dangerActions[reason] ??
        "⚠ Ensure the baby is safe and breathing normally.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Danger Type"),
        _dangerLabel(reason),

        const SizedBox(height: 12),
        _infoCard(desc),

        const SizedBox(height: 20),
        _sectionTitle("Immediate Steps"),
        _dangerActionCard(actions),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _dangerLabel(String reason) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        reason.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget _infoCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pinkSoft.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _actionCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _dangerActionCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 14,
          height: 1.5,
          color: Colors.red,
        ),
      ),
    );
  }
}

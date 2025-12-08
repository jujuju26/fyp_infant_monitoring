import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class StaffNotificationScreen extends StatefulWidget {
  final String infantId;
  final String infantName;

  const StaffNotificationScreen({
    super.key,
    required this.infantId,
    required this.infantName,
  });

  @override
  State<StaffNotificationScreen> createState() =>
      _StaffNotificationScreenState();
}

class _StaffNotificationScreenState extends State<StaffNotificationScreen> {
  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFFADADD);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<QuerySnapshot>? detectionStream;

  bool soundEnabled = true;
  bool vibrateEnabled = true;
  bool popupEnabled = true;
  double volume = 0.7;
  String cryingSound = "baby_cry_alert.wav";

  String? lastSeenDocId;

  // ---- CRY reason descriptions ----
  final Map<String, String> reasonDescriptions = {
    "hungry": "The system detected crying patterns related to hunger.",
    "tired": "The baby may be sleepy or overtired.",
    "burping": "The baby might need to burp after feeding.",
    "belly_pain": "Crying patterns indicate discomfort or stomach pain.",
    "discomfort":
    "General discomfort was detected, possibly due to heat, wet diaper, or tight clothing.",
  };

  final Map<String, String> recommendedActions = {
    "hungry":
    "• Try feeding the baby.\n• Check last feeding time.\n• Observe if crying stops after feeding.",
    "tired":
    "• Rock or gently pat the baby.\n• Reduce noise and brightness.\n• Try placing baby in a comfortable sleeping position.",
    "burping":
    "• Gently pat the baby's back.\n• Hold baby upright for a few minutes.\n• Burp between feeding intervals.",
    "belly_pain":
    "• Massage baby's belly gently.\n• Check for gas buildup.\n• Ensure baby is not constipated.\n• Consult doctor if pain persists.",
    "discomfort":
    "• Check diaper condition.\n• Adjust baby's clothing.\n• Make sure temperature is comfortable.\n• Remove anything irritating baby's skin.",
  };

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.stop);
    _init();
  }

  Future<void> _init() async {
    await _loadSettings();
    _listenToDetections();
  }

  Future<void> _loadSettings() async {
    final uid = _auth.currentUser!.uid;

    final doc = await _firestore
        .collection("staff")
        .doc(uid)
        .collection("settings")
        .doc("notifications")
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        soundEnabled = data["soundEnabled"] ?? true;
        vibrateEnabled = data["vibrateEnabled"] ?? true;
        popupEnabled = data["popupEnabled"] ?? true;
        volume = (data["volume"] ?? 0.7).toDouble();
        cryingSound = data["cryingSound"] ?? "baby_cry_alert.wav";
      });
    }

    _player.setVolume(volume);
  }

  Future<void> _saveSettings() async {
    final uid = _auth.currentUser!.uid;

    await _firestore
        .collection("staff")
        .doc(uid)
        .collection("settings")
        .doc("notifications")
        .set({
      "soundEnabled": soundEnabled,
      "vibrateEnabled": vibrateEnabled,
      "popupEnabled": popupEnabled,
      "volume": volume,
      "cryingSound": cryingSound,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // LISTEN TO FIRESTORE DETECTIONS
  void _listenToDetections() {
    final uid = _auth.currentUser!.uid;

    detectionStream?.cancel();

    detectionStream = _firestore
        .collection("staff")
        .doc(uid)
        .collection("infants")
        .doc(widget.infantId)
        .collection("detections")
        .orderBy("timestamp_unix", descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      final latest = snapshot.docs.first;
      final latestId = latest.id;

      if (lastSeenDocId == null) {
        lastSeenDocId = latestId; // first load, don't alert
        return;
      }

      if (latestId != lastSeenDocId) {
        lastSeenDocId = latestId;
        await _triggerAlert(latest.data() as Map<String, dynamic>);
      }
    });
  }

  Future<void> _triggerAlert(Map<String, dynamic> data) async {
    final String type = (data["type"] ?? "cry").toString();
    final String reasonKey = (data["reason"] ?? "").toString();
    final String time = (data["timestamp_readable"] ?? "-").toString();

    String title;
    String body;

    // ==== DANGER NOTIFICATIONS ====
    if (type == "danger_face_covered") {
      title = "⚠️ Danger: Baby's Face Covered";
      body =
      "The system detected that ${widget.infantName}'s face is covered.\n\nTime: $time";
      _showDangerPopup(title, body);
    } else if (type == "danger_rollover") {
      title = "⚠️ Danger: Unsafe Sleeping Position";
      body =
      "${widget.infantName} is in a dangerous sleeping position.\n\nTime: $time";
      _showDangerPopup(title, body);
    }

    // ==== CRY NOTIFICATION ====
    else {
      final desc = reasonDescriptions[reasonKey] ?? "Crying detected.";
      final actions = recommendedActions[reasonKey] ?? "";

      title = "Baby is Crying";
      body =
      "Reason: $reasonKey\n$desc\n\nActions:\n$actions\n\nTime: $time";
    }

    // ---- SOUND ----
    if (soundEnabled) {
      await _player.stop();
      await _player.play(
        AssetSource("sounds/$cryingSound"),
        volume: volume,
      );
    }

    // ---- VIBRATE ----
    if (vibrateEnabled && (await Vibration.hasVibrator() ?? false)) {
      Vibration.vibrate(
        duration: type.startsWith("danger") ? 1500 : 800,
      );
    }

    // ---- POPUP NOTIFICATION ----
    if (popupEnabled) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          channelKey: 'baby_alert_channel',
          title: title,
          body: body,
          wakeUpScreen: true,
          displayOnForeground: true,
          displayOnBackground: true,
        ),
      );
    }
  }

  // SHOW DANGER POPUP
  void _showDangerPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                fontFamily: "Poppins", fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontFamily: "Poppins")),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case "danger_face_covered":
        return Icons.warning_rounded;
      case "danger_rollover":
        return Icons.error_rounded;
      default:
        return Icons.child_care_rounded;
    }
  }

  Color _colorForType(String type) {
    if (type.startsWith("danger")) return Colors.red;
    return accent;
  }

  @override
  void dispose() {
    detectionStream?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: accent),
        title: Column(
          children: [
            Image.asset('assets/images/logo2.png', height: 34),
            const SizedBox(height: 2),
            Text(
              "Alerts for ${widget.infantName}",
              style:
              const TextStyle(fontFamily: "Poppins", fontSize: 13, color: accent),
            ),
          ],
        ),
        centerTitle: true,
      ),

      // BODY
      body: Column(
        children: [
          // --- SETTINGS CARD ---
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: pinkSoft.withOpacity(0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  _settingSwitch("Sound", soundEnabled, (v) {
                    setState(() => soundEnabled = v);
                    _saveSettings();
                  }),
                  _settingSwitch("Vibration", vibrateEnabled, (v) {
                    setState(() => vibrateEnabled = v);
                    _saveSettings();
                  }),
                  _settingSwitch("Popup Alerts", popupEnabled, (v) {
                    setState(() => popupEnabled = v);
                    _saveSettings();
                  }),
                ],
              ),
            ),
          ),

          // --- DETECTIONS LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection("staff")
                  .doc(uid)
                  .collection("infants")
                  .doc(widget.infantId)
                  .collection("detections")
                  .orderBy("timestamp_unix", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: accent));
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No detections yet",
                      style: TextStyle(fontFamily: "Poppins"),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final type = data["type"] ?? "cry";
                    final time = data["timestamp_readable"] ?? "-";
                    final reason = data["reason"] ?? "";

                    String title;
                    String subtitle;

                    if (type == "danger_face_covered") {
                      title = "Danger: Face Covered";
                      subtitle = "Baby's face is covered.\n$time";
                    } else if (type == "danger_rollover") {
                      title = "Danger: Unsafe Sleeping Position";
                      subtitle = "Baby is in a hazardous position.\n$time";
                    } else {
                      title = "Baby is Crying ($reason)";
                      subtitle =
                      "${reasonDescriptions[reason] ?? 'Crying detected'}\n$time";
                    }

                    return _notificationCard(
                      icon: _iconForType(type),
                      color: _colorForType(type),
                      title: title,
                      subtitle: subtitle,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // UI COMPONENTS
  Widget _settingSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontFamily: "Poppins", fontSize: 14)),
        ),
        Switch(
          value: value,
          activeColor: accent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _notificationCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color == Colors.red
            ? Colors.red.shade50
            : pinkSoft.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "$title\n$subtitle",
              style: const TextStyle(
                fontFamily: "Poppins",
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

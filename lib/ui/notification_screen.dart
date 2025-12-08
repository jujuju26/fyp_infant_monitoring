import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import 'logout_success_screen.dart';
import 'notification_detail_screen.dart';
import 'notification_settings_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final AudioPlayer _player = AudioPlayer();

  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFFADADD);

  /// TODO: later you will pass this from InfantMonitoring screen
  String infantId = "NEa7O0FMT00FKM2Rew6w";

  // SETTINGS
  bool soundEnabled = true;
  bool vibrateEnabled = true;
  bool popupEnabled = true;
  double volume = 0.7;
  String cryingSound = "baby_cry_alert.wav";

  // Detect new document
  String? lastSeenDocId;
  StreamSubscription? detectionStream;

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

  // Load from Firestore: parent > settings > notifications
  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("parent")
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

  // Listen to Firestore for new detections (cry + danger)
  void _listenToDetections() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    detectionStream = FirebaseFirestore.instance
        .collection("parent")
        .doc(uid)
        .collection("infants")
        .doc(infantId)
        .collection("detections")
        .orderBy("timestamp_unix", descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      final latest = snapshot.docs.first;
      final latestId = latest.id;

      // First time opening screen -> set baseline, no alert
      if (lastSeenDocId == null) {
        lastSeenDocId = latestId;
        return;
      }

      // If a NEW detection (new document ID), trigger alert
      if (latestId != lastSeenDocId) {
        lastSeenDocId = latestId;
        await _triggerAlert(latest.data() as Map<String, dynamic>);
      }
    });
  }

  // Trigger sound, vibration and popup depending on type
  Future<void> _triggerAlert(Map<String, dynamic> data) async {
    final String type = (data["type"] ?? "cry").toString(); // cry / danger
    final String reason = (data["reason"] ?? "Unknown").toString();
    final String dangerType = (data["dangerType"] ?? "face_covered").toString();

    // ---------- Build title & body ----------
    String title;
    String body;

    if (type == "danger") {
      // Face covered / unsafe position
      title = "Danger! Baby might be in unsafe position";
      String niceDangerText;
      switch (dangerType) {
        case "face_covered":
          niceDangerText = "Face may be covered. Please check immediately.";
          break;
        case "unsafe_position":
          niceDangerText = "Unsafe sleeping position detected.";
          break;
        default:
          niceDangerText =
          "Potential danger detected. Please check your baby.";
      }
      body = niceDangerText;
    } else {
      // Default: cry
      title = "Baby is Crying!";
      body = "Reason: $reason";
    }

    // ---------- SOUND ----------
    if (soundEnabled) {
      try {
        await _player.stop();
        // For now reuse the same alert sound for both cry + danger
        await _player.play(
          AssetSource("sounds/$cryingSound"),
          volume: volume,
        );
      } catch (e) {
        debugPrint("Sound error: $e");
      }
    }

    // ---------- VIBRATION ----------
    if (vibrateEnabled && (await Vibration.hasVibrator() ?? false)) {
      if (type == "danger") {
        // Stronger vibration pattern for danger
        Vibration.vibrate(
          pattern: [0, 800, 300, 800],
        );
      } else {
        Vibration.vibrate(duration: 1000);
      }
    }

    // ---------- POPUP ----------
    if (popupEnabled) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          channelKey: 'baby_alert_channel',
          title: title,
          body: body,
          displayOnForeground: true,
          displayOnBackground: true,
          wakeUpScreen: true,
          notificationLayout: NotificationLayout.Default,
        ),
      );
    }
  }

  @override
  void dispose() {
    detectionStream?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: accent),
        title: Image.asset('assets/images/logo2.png', height: 42),
      ),
      drawer: Drawer(
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
            _drawerItem(
              Icons.settings,
              "Notification Settings",
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            _drawerItem(
              Icons.logout,
              "Logout",
                  () async {
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("parent")
            .doc(uid)
            .collection("infants")
            .doc(infantId)
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
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final String timeText =
              (data["timestamp_readable"] ?? "-").toString();
              final String type =
              (data["type"] ?? "cry").toString(); // cry / danger
              final String? reason =
              data["reason"] != null ? data["reason"].toString() : null;
              final String? dangerType = data["dangerType"] != null
                  ? data["dangerType"].toString()
                  : null;

              return _notificationCard(
                time: timeText,
                type: type,
                reason: reason,
                dangerType: dangerType,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationDetailScreen(
                        detectionId: doc.id,
                        infantId: infantId,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Drawer item widget
  static Widget _drawerItem(
      IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(fontFamily: "Poppins", fontSize: 15),
      ),
      onTap: onTap,
    );
  }

  // Notification card widget: supports CRY + DANGER
  Widget _notificationCard({
    required String time,
    required String type,
    required String? reason,
    required String? dangerType,
    required VoidCallback onTap,
  }) {
    final bool isDanger = type == "danger";

    String mainText;
    if (isDanger) {
      String niceDanger;
      switch (dangerType) {
        case "face_covered":
          niceDanger = "Face may be covered. Please check immediately.";
          break;
        case "unsafe_position":
          niceDanger = "Unsafe sleeping position detected.";
          break;
        default:
          niceDanger =
          "Potential danger detected. Please check your baby.";
      }
      mainText = "Danger detected\n$niceDanger\n$time";
    } else {
      final String r = reason ?? "Unknown";
      mainText = "Baby is crying\nReason: $r\n$time";
    }

    final Color cardColor =
    isDanger ? Colors.red.shade50 : pinkSoft.withOpacity(0.35);
    final Color iconColor = isDanger ? Colors.red : accent;
    final IconData iconData =
    isDanger ? Icons.warning_amber_rounded : Icons.child_care_rounded;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDanger ? Colors.redAccent.withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.4)),
              ),
              child: Icon(iconData, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                mainText,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: isDanger ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

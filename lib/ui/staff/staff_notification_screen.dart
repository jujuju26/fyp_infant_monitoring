import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logout_success_screen.dart';
import 'staff_notification_detail_screen.dart';
import 'staff_notification_settings_screen.dart';

class StaffNotificationScreen extends StatefulWidget {
  const StaffNotificationScreen({super.key});

  @override
  State<StaffNotificationScreen> createState() =>
      _StaffNotificationScreenState();
}

class _StaffNotificationScreenState extends State<StaffNotificationScreen> {
  final AudioPlayer _player = AudioPlayer();

  static const accent = Color(0xFFC2868B);
  static const pinkSoft = Color(0xFFFADADD);

  String infantId = "pED9hzuaO7U3tFd1bvWQ";

  bool soundEnabled = true;
  bool vibrateEnabled = true;
  bool popupEnabled = true;
  double volume = 0.7;
  String cryingSound = "baby_cry_alert.wav";

  String? lastSeenDocId;
  StreamSubscription? detectionSubscription;

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.stop);
    _loadSettings();
    _listenToNewDetections();
  }

  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("staff")
        .doc(uid)
        .collection("settings")
        .doc("notifications")
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      soundEnabled = data["soundEnabled"] ?? true;
      vibrateEnabled = data["vibrateEnabled"] ?? true;
      popupEnabled = data["popupEnabled"] ?? true;
      volume = (data["volume"] ?? 0.7).toDouble();
      cryingSound = data["cryingSound"] ?? "baby_cry_alert.wav";
    }

    _player.setVolume(volume);
    setState(() {});
  }

  void _listenToNewDetections() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    detectionSubscription = FirebaseFirestore.instance
        .collection("staff")
        .doc(uid)
        .collection("infants")
        .doc(infantId)
        .collection("detections")
        .orderBy("timestamp_unix")
        .limitToLast(1) // MUCH FASTER
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
        await _triggerAlert(latest.data());
      }
    });
  }

  Future<void> _triggerAlert(Map<String, dynamic> data) async {
    // SOUND
    if (soundEnabled) {
      try {
        await _player.stop();
        await _player.play(
          AssetSource("sounds/$cryingSound"),
          volume: volume,
        );
      } catch (e) {
        print("Sound error: $e");
      }
    }

    // VIBRATE
    if (vibrateEnabled && (await Vibration.hasVibrator() ?? false)) {
      Vibration.vibrate(duration: 1000);
    }

    // POPUP NOTIFICATION
    if (popupEnabled) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'baby_alert_channel',
          title: "Baby is Crying!",
          body: "Tap to view details",
          wakeUpScreen: true,
          displayOnForeground: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    detectionSubscription?.cancel();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: accent),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),

      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
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
              'Notification Settings',
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StaffNotificationSettingsScreen(),
                  ),
                );
              },
            ),

            const Divider(),

            _drawerItem(
              Icons.logout,
              'Logout',
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
            .collection("staff")
            .doc(uid)
            .collection("infants")
            .doc(infantId)
            .collection("detections")
            .orderBy("timestamp_unix", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
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
            itemBuilder: (context, index) {
              final detectionDoc = docs[index];
              final data =
              detectionDoc.data() as Map<String, dynamic>;

              final timeText = data["timestamp_readable"] ?? "-";

              return _notificationCard(
                timeText: timeText,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffNotificationDetailScreen(
                        detectionId: detectionDoc.id,
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

  static Widget _drawerItem(
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _notificationCard({
    required String timeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pinkSoft.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: const Icon(
                Icons.child_care_rounded,
                color: accent,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "Baby is crying\n$timeText",
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

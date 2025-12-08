import 'package:audioplayers/audioplayers.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class StaffNotificationSettingsScreen extends StatefulWidget {
  const StaffNotificationSettingsScreen({super.key});

  @override
  State<StaffNotificationSettingsScreen> createState() =>
      _StaffNotificationSettingsScreenState();
}

class _StaffNotificationSettingsScreenState
    extends State<StaffNotificationSettingsScreen> {
  static const accent = Color(0xFFC2868B);

  final AudioPlayer _player = AudioPlayer();
  final String staffUid = FirebaseAuth.instance.currentUser!.uid;

  bool soundEnabled = true;
  bool vibrateEnabled = true;
  bool popupEnabled = true;
  double volume = 0.7;

  /// renamed: supports cry + danger alerts
  String alertSound = "baby_cry_alert.wav";

  /// future: you can add more sounds here later
  final List<String> alertSounds = [
    "baby_cry_alert.wav",
    "default_notification.wav",
  ];

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadSettings();
  }

  Future<void> _initNotifications() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'baby_alert_channel',
          channelName: 'Baby Alerts',
          channelDescription: 'Cry alerts + danger alerts (face covered & rollover)',
          defaultColor: Colors.pinkAccent,
          importance: NotificationImportance.Max,
          defaultRingtoneType: DefaultRingtoneType.Notification,
          playSound: false, // we play sound manually using audioplayers
          enableVibration: false, // vibration handled manually
        ),
      ],
    );

    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('staff')
        .doc(staffUid)
        .collection('settings')
        .doc('notifications')
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        soundEnabled = data['soundEnabled'] ?? true;
        vibrateEnabled = data['vibrateEnabled'] ?? true;
        popupEnabled = data['popupEnabled'] ?? true;
        volume = (data['volume'] ?? 0.7).toDouble();
        alertSound = data['cryingSound'] ?? "baby_cry_alert.wav";
      });
      _player.setVolume(volume);
    }
  }

  Future<void> _saveSettings() async {
    await FirebaseFirestore.instance
        .collection('staff')
        .doc(staffUid)
        .collection('settings')
        .doc('notifications')
        .set({
      'soundEnabled': soundEnabled,
      'vibrateEnabled': vibrateEnabled,
      'popupEnabled': popupEnabled,
      'volume': volume,
      'cryingSound': alertSound,
    }, SetOptions(merge: true));
  }

  Future<void> playPreview(String sound) async {
    await _player.stop();
    await _player.play(
      AssetSource("sounds/$sound"),
      volume: volume,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Notification Settings",
          style: TextStyle(
            fontFamily: "Poppins",
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("General Settings"),
            _switchTile(
              title: "Enable Alert Sound",
              value: soundEnabled,
              onChanged: (v) {
                setState(() => soundEnabled = v);
                _saveSettings();
              },
            ),
            _switchTile(
              title: "Vibrate on Alert",
              value: vibrateEnabled,
              onChanged: (v) {
                setState(() => vibrateEnabled = v);
                _saveSettings();
              },
            ),
            _switchTile(
              title: "Show Popup Notification",
              value: popupEnabled,
              onChanged: (v) {
                setState(() => popupEnabled = v);
                _saveSettings();
              },
            ),

            const SizedBox(height: 25),

            _sectionTitle("Volume"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: _boxDecoration(),
              child: Row(
                children: [
                  const Icon(Icons.volume_up, color: Colors.black54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      onChanged: (v) {
                        setState(() => volume = v);
                        _player.setVolume(v);
                        _saveSettings();
                      },
                      activeColor: accent,
                      thumbColor: accent,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            _sectionTitle("Alert Sound (Cry + Danger)"),
            _soundPicker(
              currentSound: alertSound,
              soundList: alertSounds,
              onChanged: (v) {
                setState(() => alertSound = v!);
                _saveSettings();
              },
            ),

            const SizedBox(height: 12),
            const Text(
              "This sound will play for ALL alerts:\n• Crying alerts\n• Face covered danger\n• Rollover danger",
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 12,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: _boxDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: "Poppins",
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _soundPicker({
    required String currentSound,
    required List<String> soundList,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _boxDecoration(),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: currentSound,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: "Select Sound",
              labelStyle: TextStyle(fontFamily: "Poppins"),
            ),
            items: soundList.map((s) {
              return DropdownMenuItem(
                value: s,
                child: Text(s, style: const TextStyle(fontFamily: "Poppins")),
              );
            }).toList(),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => playPreview(currentSound),
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text(
                "Preview Sound",
                style: TextStyle(fontFamily: "Poppins"),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black12),
      boxShadow: [
        BoxShadow(
          color: Colors.black12.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

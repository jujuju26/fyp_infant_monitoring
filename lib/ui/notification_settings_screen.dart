import 'package:audioplayers/audioplayers.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const accent = Color(0xFFC2868B);

  final AudioPlayer _player = AudioPlayer();
  final String parentUid = FirebaseAuth.instance.currentUser!.uid;

  bool soundEnabled = true;
  bool vibrateEnabled = true;
  bool popupEnabled = true;
  double volume = 0.7;

  // Crying sounds
  String cryingSound = "baby_cry_alert.wav";
  final List<String> cryingSounds = [
    "baby_cry_alert.wav",
    "default_notification.wav",
  ];

  // DANGER alert sounds
  bool dangerSoundEnabled = true;
  String dangerSound = "danger_alert.wav";
  final List<String> dangerSounds = [
    "danger_alert.wav",
    "alarm.wav",
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'baby_alert_channel',
          channelName: 'Baby Alerts',
          channelDescription: 'Alerts for baby crying and danger detection',
          importance: NotificationImportance.Max,
          playSound: false,
          enableVibration: false,
        ),
      ],
    );

    if (!await AwesomeNotifications().isNotificationAllowed()) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  // ============================
  // LOAD SETTINGS
  // ============================
  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('parent')
        .doc(parentUid)
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
        cryingSound = data['cryingSound'] ?? "baby_cry_alert.wav";

        // NEW danger fields
        dangerSoundEnabled = data['dangerSoundEnabled'] ?? true;
        dangerSound = data['dangerSound'] ?? "danger_alert.wav";
      });
    }

    _player.setVolume(volume);
  }

  // ============================
  // SAVE SETTINGS
  // ============================
  Future<void> _saveSettings() async {
    await FirebaseFirestore.instance
        .collection('parent')
        .doc(parentUid)
        .collection('settings')
        .doc('notifications')
        .set({
      'soundEnabled': soundEnabled,
      'vibrateEnabled': vibrateEnabled,
      'popupEnabled': popupEnabled,
      'volume': volume,
      'cryingSound': cryingSound,

      // NEW danger alert settings
      'dangerSoundEnabled': dangerSoundEnabled,
      'dangerSound': dangerSound,
    });
  }

  // ============================
  // PREVIEW SOUND PLAYBACK
  // ============================
  Future<void> playPreview(String file) async {
    await _player.stop();
    await _player.play(AssetSource("sounds/$file"), volume: volume);
  }

  Future<void> playDangerPreview(String file) async {
    await _player.stop();
    await _player.play(AssetSource("sounds/$file"), volume: volume);
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
        backgroundColor: Colors.white,
        centerTitle: true,
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
              title: "Enable Notification Sound",
              value: soundEnabled,
              onChanged: (v) {
                setState(() => soundEnabled = v);
                _saveSettings();
              },
            ),
            _switchTile(
              title: "Vibrate",
              value: vibrateEnabled,
              onChanged: (v) {
                setState(() => vibrateEnabled = v);
                _saveSettings();
              },
            ),
            _switchTile(
              title: "Show Popup Alert",
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
                      min: 0.0,
                      max: 1.0,
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

            // ============================
            // CRYING SOUND SECTION
            // ============================
            const SizedBox(height: 25),
            _sectionTitle("Crying Alert Sound"),

            _soundPicker(
              title: "Select Crying Sound",
              currentSound: cryingSound,
              soundList: cryingSounds,
              onChanged: (v) {
                setState(() => cryingSound = v!);
                _saveSettings();
              },
              onPreview: () => playPreview(cryingSound),
            ),

            // ============================
            // DANGER SOUND SECTION
            // ============================
            const SizedBox(height: 25),
            _sectionTitle("Danger Alert Sound"),

            _switchTile(
              title: "Enable Danger Alert Sound",
              value: dangerSoundEnabled,
              onChanged: (v) {
                setState(() => dangerSoundEnabled = v);
                _saveSettings();
              },
            ),

            _soundPicker(
              title: "Select Danger Sound",
              currentSound: dangerSound,
              soundList: dangerSounds,
              onChanged: (v) {
                setState(() => dangerSound = v!);
                _saveSettings();
              },
              onPreview: () => playDangerPreview(dangerSound),
            ),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  // ============================
  // UI HELPERS
  // ============================

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
          Text(
            title,
            style: const TextStyle(
              fontFamily: "Poppins",
              fontSize: 15,
              color: Colors.black87,
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
    required String title,
    required String currentSound,
    required List<String> soundList,
    required Function(String?) onChanged,
    required Function() onPreview,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _boxDecoration(),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: currentSound,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: title,
              labelStyle: const TextStyle(fontFamily: "Poppins"),
            ),
            items: soundList
                .map((s) => DropdownMenuItem(
              value: s,
              child: Text(s,
                  style: const TextStyle(fontFamily: "Poppins")),
            ))
                .toList(),
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
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

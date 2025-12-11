import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InfantLiveMonitorScreen extends StatefulWidget {
  final String infantId;
  final Map<String, dynamic> infantData;

  const InfantLiveMonitorScreen({
    super.key,
    required this.infantId,
    required this.infantData,
  });

  @override
  _InfantLiveMonitorScreenState createState() =>
      _InfantLiveMonitorScreenState();
}

class _InfantLiveMonitorScreenState extends State<InfantLiveMonitorScreen> {
  late http.Client _httpClient;

  Uint8List? currentFrame;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _startMJPEGStream();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Future<void> _startMJPEGStream() async {
    const streamUrl = "http://172.20.10.4:8080/stream.mjpg";

    final request = http.Request("GET", Uri.parse(streamUrl));
    request.headers["Connection"] = "keep-alive";

    try {
      final response = await _httpClient.send(request);

      if (response.statusCode == 200) {
        List<int> buffer = [];

        response.stream.listen((chunk) {
          buffer.addAll(chunk);
          _extractJPEG(buffer);
        }, onError: (e) {
          print("Stream error: $e");
          Future.delayed(const Duration(seconds: 1), _startMJPEGStream);
        }, onDone: () {
          print("Stream closed by server.");
          Future.delayed(const Duration(seconds: 1), _startMJPEGStream);
        });
      } else {
        print("Failed to connect to MJPEG stream.");
      }
    } catch (e) {
      print("Connection error: $e");
      Future.delayed(const Duration(seconds: 1), _startMJPEGStream);
    }
  }

  void _extractJPEG(List<int> data) {
    try {
      int start = _find(data, [0xFF, 0xD8]); // JPEG start marker
      if (start == -1) return;

      int end = _find(data, [0xFF, 0xD9], start + 2); // JPEG end marker
      if (end == -1) return;

      List<int> jpeg = data.sublist(start, end + 2);

      // remove processed bytes
      data.removeRange(0, end + 2);

      setState(() {
        currentFrame = Uint8List.fromList(jpeg); // update frame
      });
    } catch (e) {
      print("JPEG parse error: $e");
    }
  }

  int _find(List<int> data, List<int> seq, [int start = 0]) {
    for (int i = start; i < data.length - seq.length; i++) {
      bool matched = true;
      for (int j = 0; j < seq.length; j++) {
        if (data[i + j] != seq[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC2868B);
    const lightPink = Color(0xFFFADADD);

    final String name = (widget.infantData['name'] ?? 'Infant').toString();
    final String gender = (widget.infantData['gender'] ?? '-').toString();
    final String weight = (widget.infantData['weight'] ?? '-').toString();
    final String height = (widget.infantData['height'] ?? '-').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: accent,
        elevation: 0,
        title: const Text(
          "Infant Monitoring",
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: lightPink,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'I',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Gender: $gender",
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          "Ht: $height cm  •  Wt: $weight kg",
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: currentFrame == null
                    ? Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Text(
                    "Connecting to camera...",
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: "Poppins",
                      fontSize: 14,
                    ),
                  ),
                )
                    : Image.memory(
                  currentFrame!,
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statusChip(
                  label: "Cry status",
                  value: "Calm",
                  color: Colors.green,
                ),
                _statusChip(
                  label: "Sleep position",
                  value: "Safe",
                  color: Colors.blue,
                ),
                _statusChip(
                  label: "Last alert",
                  value: "--",
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

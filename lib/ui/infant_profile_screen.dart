import 'package:flutter/material.dart';
import '../../models/infant_model.dart';
import 'infant_profile_edit_screen.dart';

class InfantProfileScreen extends StatelessWidget {
  final Infant infant;
  const InfantProfileScreen({super.key, required this.infant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(infant.name),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFC2868B)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(radius: 44, child: Text(infant.name[0]), backgroundColor: const Color(0xFFFADADD)),
            const SizedBox(height: 14),
            Text(infant.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC2868B))),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _infoRow(Icons.cake, 'DOB: ${infant.dob}'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.meeting_room, 'Room: ${infant.room}'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.note, 'Notes: ${infant.notes.isEmpty ? "—" : infant.notes}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => InfantProfileEditScreen(infant: infant, isNew: false)));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC2868B)),
              child: const Text("Edit"),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC2868B)),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

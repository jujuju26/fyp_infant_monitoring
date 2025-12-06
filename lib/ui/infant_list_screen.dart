import 'package:flutter/material.dart';
import '../../models/infant_model.dart';
import 'infant_profile_edit_screen.dart';
import 'infant_profile_screen.dart';

class InfantListScreen extends StatelessWidget {
  InfantListScreen({super.key});

  final List<Infant> demo = [
    Infant(id: "i1", name: "Baby A", dob: "2025-04-01", room: "Room 1"),
    Infant(id: "i2", name: "Baby B", dob: "2025-03-25", room: "Room 2"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Infant Management", style: TextStyle(color: Color(0xFFC2868B))),
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFC2868B)),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: demo.length,
        itemBuilder: (context, index) {
          final infant = demo[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(child: Text(infant.name[0])),
              title: Text(infant.name),
              subtitle: Text("Room: ${infant.room} • DOB: ${infant.dob}"),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => InfantProfileScreen(infant: infant)));
              },
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => InfantProfileEditScreen(infant: infant, isNew: false)));
                  } else if (value == 'delete') {
                    // TODO: delete infant
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC2868B),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const InfantProfileEditScreen(isNew: true)));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

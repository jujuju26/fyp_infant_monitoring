import 'package:flutter/material.dart';
import '../../models/infant_model.dart';

class InfantProfileEditScreen extends StatefulWidget {
  final Infant? infant;
  final bool isNew;
  const InfantProfileEditScreen({super.key, this.infant, required this.isNew});

  @override
  State<InfantProfileEditScreen> createState() => _InfantProfileEditScreenState();
}

class _InfantProfileEditScreenState extends State<InfantProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _roomCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final i = widget.infant;
    _nameCtrl = TextEditingController(text: i?.name ?? '');
    _dobCtrl = TextEditingController(text: i?.dob ?? '');
    _roomCtrl = TextEditingController(text: i?.room ?? '');
    _notesCtrl = TextEditingController(text: i?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _roomCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      // TODO: save to Firestore/backend
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isNew ? "Add Infant" : "Edit Infant";
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFC2868B)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Baby name"),
                validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dobCtrl,
                decoration: const InputDecoration(labelText: "DOB (YYYY-MM-DD)"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomCtrl,
                decoration: const InputDecoration(labelText: "Room"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: "Notes"),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC2868B)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text("Save"),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

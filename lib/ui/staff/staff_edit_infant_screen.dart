import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffEditInfantScreen extends StatefulWidget {
  final String infantId;
  final Map<String, dynamic> infantData;

  const StaffEditInfantScreen({
    super.key,
    required this.infantId,
    required this.infantData,
  });

  @override
  State<StaffEditInfantScreen> createState() => _StaffEditInfantScreen();
}

class _StaffEditInfantScreen extends State<StaffEditInfantScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameC;
  late TextEditingController _heightC;
  late TextEditingController _weightC;
  late TextEditingController _birthC;

  String? _selectedGender;
  DateTime? _birthDate;

  bool _isSaving = false;

  final Color accent = const Color(0xFFC2868B);
  final Color pinkSoft = const Color(0xFFFADADD);

  @override
  void initState() {
    super.initState();

    final data = widget.infantData;

    _nameC = TextEditingController(text: data['name']);
    _heightC = TextEditingController(text: data['height'].toString());
    _weightC = TextEditingController(text: data['weight'].toString());

    // Load birthdate
    if (data['birthDate'] != null) {
      _birthDate = (data['birthDate'] as Timestamp).toDate();
      _birthC = TextEditingController(
        text: '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
      );
    } else {
      _birthC = TextEditingController();
    }

    _selectedGender = data['gender'];
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthC.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedData = {
        'name': _nameC.text.trim(),
        'gender': _selectedGender,
        'height': double.tryParse(_heightC.text.trim()) ?? 0,
        'weight': double.tryParse(_weightC.text.trim()) ?? 0,
        'birthDate': _birthDate,
        'updatedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('staff')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('infants')
          .doc(widget.infantId)
          .update(updatedData);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _deleteInfant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Infant"),
        content: const Text("Are you sure you want to delete this infant?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('staff')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('infants')
          .doc(widget.infantId)
          .delete();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Edit Infant",
          style: TextStyle(
            color: Color(0xFFC2868B),
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFC2868B)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(
                  label: "Infant Name",
                  controller: _nameC,
                  hint: "Enter infant name",
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _pickBirthDate,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      label: "Date of Birth",
                      controller: _birthC,
                      hint: "Select birth date",
                      suffixIcon: const Icon(Icons.date_range),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: _dropdownDecoration(),
                  items: const [
                    DropdownMenuItem(value: "Male", child: Text("Male")),
                    DropdownMenuItem(value: "Female", child: Text("Female")),
                  ],
                  onChanged: (v) => setState(() => _selectedGender = v),
                  validator: (v) => v == null ? "Select gender" : null,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: "Height (cm)",
                  controller: _heightC,
                  hint: "Enter height",
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: "Weight (kg)",
                  controller: _weightC,
                  hint: "Enter weight",
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 30),

                _isSaving
                    ? const CircularProgressIndicator()
                    : Column(
                  children: [
                    ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pinkSoft,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Save Changes"),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _deleteInfant,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Delete Infant"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: accent)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (v) => v == null || v.isEmpty ? "Please enter $label" : null,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

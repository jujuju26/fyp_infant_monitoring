import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditInfantScreen extends StatefulWidget {
  final String infantId;
  final Map<String, dynamic> infantData;

  const EditInfantScreen({
    super.key,
    required this.infantId,
    required this.infantData,
  });

  @override
  State<EditInfantScreen> createState() => _EditInfantScreenState();
}

class _EditInfantScreenState extends State<EditInfantScreen> {
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

    _nameC = TextEditingController(text: data['name'] ?? "");
    _heightC = TextEditingController(text: "${data['height'] ?? ''}");
    _weightC = TextEditingController(text: "${data['weight'] ?? ''}");

    // Birthdate
    if (data['birthDate'] != null && data['birthDate'] is Timestamp) {
      _birthDate = (data['birthDate'] as Timestamp).toDate();
      _birthC = TextEditingController(
        text: "${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}",
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
      firstDate: DateTime(2018),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthC.text = "${picked.day}/${picked.month}/${picked.year}";
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

      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('parent')
          .doc(uid)
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
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('parent')
          .doc(uid)
          .collection('infants')
          .doc(widget.infantId)
          .delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Infant deleted")),
        );
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
                _buildFormCard(),

                const SizedBox(height: 40),

                _isSaving
                    ? const CircularProgressIndicator(color: Color(0xFFC2868B))
                    : _buildSaveButton(),

                const SizedBox(height: 20),

                _buildDeleteButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6C9CC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            offset: const Offset(0, 3),
            blurRadius: 6,
          )
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            label: "Infant Name",
            controller: _nameC,
            hint: "Enter infant name",
          ),
          const SizedBox(height: 16),

          // Birthdate
          GestureDetector(
            onTap: _pickBirthDate,
            child: AbsorbPointer(
              child: _buildTextField(
                label: "Date of Birth",
                controller: _birthC,
                hint: "Select birthdate",
                suffixIcon: const Icon(Icons.date_range, color: Color(0xFFC2868B)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gender
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Gender",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 6),

          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: _dropdownDecoration(),
            dropdownColor: const Color(0xFFFFF9FA),
            items: const [
              DropdownMenuItem(value: "Male", child: Text("Male")),
              DropdownMenuItem(value: "Female", child: Text("Female")),
            ],
            onChanged: (v) => setState(() => _selectedGender = v),
            validator: (v) => v == null ? "Please select gender" : null,
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
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveChanges,
      style: ElevatedButton.styleFrom(
        backgroundColor: pinkSoft,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: const Text(
        "Save Changes",
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return ElevatedButton(
      onPressed: _deleteInfant,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: const Text(
        "Delete Infant",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  // ---------- Reusable UI ----------

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
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD8B6B9)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent),
            ),
          ),
          validator: (v) => v == null || v.isEmpty ? "Please enter $label" : null,
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8B6B9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent),
      ),
    );
  }
}

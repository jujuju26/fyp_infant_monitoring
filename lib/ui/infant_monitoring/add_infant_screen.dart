import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddInfantScreen extends StatefulWidget {
  const AddInfantScreen({super.key});

  @override
  State<AddInfantScreen> createState() => _AddInfantScreenState();
}

class _AddInfantScreenState extends State<AddInfantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _heightC = TextEditingController();
  final _weightC = TextEditingController();
  final _birthC = TextEditingController();

  String? _selectedGender;
  DateTime? _birthDate;

  bool _isSaving = false;

  final Color accent = const Color(0xFFC2868B);
  final Color pinkSoft = const Color(0xFFFADADD);

  @override
  void dispose() {
    _nameC.dispose();
    _heightC.dispose();
    _weightC.dispose();
    _birthC.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 30)),
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

  Future<void> _saveInfant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select birthdate")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not signed in");

      final infantData = {
        'name': _nameC.text.trim(),
        'gender': _selectedGender,
        'birthDate': _birthDate,
        'height': double.tryParse(_heightC.text.trim()) ?? 0,
        'weight': double.tryParse(_weightC.text.trim()) ?? 0,
        'createdAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('parent')
          .doc(user.uid)
          .collection('infants')
          .add(infantData);

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving infant: $e")),
      );
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Add Infant',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Color(0xFFC2868B),
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

                // Birthdate
                GestureDetector(
                  onTap: _pickBirthDate,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      label: "Date of Birth",
                      controller: _birthC,
                      hint: "Select date",
                      suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFFC2868B)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Gender dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Gender",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFFC2868B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFD8B6B9)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFC2868B)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Male", child: Text("Male")),
                        DropdownMenuItem(value: "Female", child: Text("Female")),
                      ],
                      onChanged: (value) => setState(() => _selectedGender = value),
                      validator: (value) => value == null ? "Please select gender" : null,
                    ),
                  ],
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

                const SizedBox(height: 40),

                _isSaving
                    ? const CircularProgressIndicator(color: Color(0xFFC2868B))
                    : ElevatedButton(
                  onPressed: _saveInfant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkSoft,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Save Infant",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Reusable Text Field ----------
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
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFC2868B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFD8B6B9)),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: accent),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) =>
          value == null || value.isEmpty ? "Please enter $label" : null,
        ),
      ],
    );
  }
}

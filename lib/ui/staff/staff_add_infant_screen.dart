import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffAddInfantScreen extends StatefulWidget {
  const StaffAddInfantScreen({super.key});

  @override
  State<StaffAddInfantScreen> createState() => _StaffAddInfantScreen();
}

class _StaffAddInfantScreen extends State<StaffAddInfantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _heightC = TextEditingController();
  final _weightC = TextEditingController();
  final _birthC = TextEditingController();

  String? _selectedGender;
  DateTime? _birthDate;

  final Color accent = const Color(0xFFC2868B);
  final Color pinkSoft = const Color(0xFFFADADD);
  bool _isSaving = false;

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
        _birthC.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _saveInfant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');

      final infantData = {
        'name': _nameC.text.trim(),
        'gender': _selectedGender,
        'birthDate': _birthDate,
        'height': double.tryParse(_heightC.text.trim()) ?? 0,
        'weight': double.tryParse(_weightC.text.trim()) ?? 0,
        'createdAt': Timestamp.now(),
      };

      // Always save under staff's collection
      await FirebaseFirestore.instance
          .collection('staff')
          .doc(user.uid)
          .collection('infants')
          .add(infantData);

      setState(() => _isSaving = false);
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving infant: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Add Infant',
          style: TextStyle(
            color: Color(0xFFC2868B),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  label: 'Infant Name',
                  controller: _nameC,
                  hint: 'Enter infant name',
                ),
                const SizedBox(height: 16),

                // Date of Birth - separate row
                GestureDetector(
                  onTap: _pickBirthDate,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      label: 'Date of Birth',
                      controller: _birthC,
                      hint: 'Select date',
                      suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFFC2868B)),
                      validatorText: _birthDate == null ? 'Please select date' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Gender - separate row
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFFC2868B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFC2868B), width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFD8B6B9), width: 1.0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      dropdownColor: const Color(0xFFFFF9FA),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC2868B), size: 28),
                      borderRadius: BorderRadius.circular(15),
                      value: _selectedGender,
                      hint: const Text(
                        'Select gender',
                        style: TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 14),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Male',
                          child: Row(
                            children: [
                              Icon(Icons.male, color: Color(0xFFC2868B)),
                              SizedBox(width: 8),
                              Text('Male', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF5F4448), fontSize: 15)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Row(
                            children: [
                              Icon(Icons.female, color: Color(0xFFC2868B)),
                              SizedBox(width: 8),
                              Text('Female', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF5F4448), fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _selectedGender = value),
                      validator: (value) => value == null ? 'Please select gender' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Height (cm)',
                  controller: _heightC,
                  hint: 'Enter height in cm',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Weight (kg)',
                  controller: _weightC,
                  hint: 'Enter weight in kg',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 160),

                // Save Button
                _isSaving
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFC2868B)))
                    : ElevatedButton(
                  onPressed: _saveInfant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinkSoft,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.black26, width: 1.2),
                    ),
                    elevation: 3,
                    shadowColor: Colors.black26,
                  ),
                  child: const Text(
                    'Save Infant',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black,
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

  // Reusable text field
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? validatorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFC2868B))),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Poppins'),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD8B6B9), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC2868B), width: 1.5),
            ),
          ),
          validator: (value) => validatorText ?? (value == null || value.isEmpty ? 'Please enter $label' : null),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'parent_home_screen.dart';

class BabyProfileScreen extends StatefulWidget {
  const BabyProfileScreen({super.key});

  @override
  State<BabyProfileScreen> createState() => _BabyProfileScreenState();
}

class _BabyProfileScreenState extends State<BabyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _babyNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime? _birthDate;
  String? _selectedGender;
  bool _isSaving = false;

  // Getter to format the birth date string
  String get _birthDateText {
    if (_birthDate == null) return '';
    return '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
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
        "name": _babyNameController.text.trim(),
        "date_of_birth": _birthDate,
        "gender": _selectedGender,
        "height_cm": double.tryParse(_heightController.text.trim()) ?? 0,
        "weight_kg": double.tryParse(_weightController.text.trim()) ?? 0,
        "created_at": DateTime.now(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('infants')
          .add(infantData);

      setState(() => _isSaving = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ParentHomeScreen()),
      );
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
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable content
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back Button + Title
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFFC2868B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Add New Infant',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC2868B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Logo
                    Image.asset('assets/images/logo2.png', height: 100),
                    const SizedBox(height: 50),

                    // Name
                    _buildTextField(
                      label: 'Name',
                      controller: _babyNameController,
                      hint: 'Enter baby name',
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth - separate row
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: _buildTextField(
                          label: 'Date of Birth',
                          controller: TextEditingController(text: _birthDateText),
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
                          dropdownColor: const Color(0xFFFFF9FA),
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC2868B), size: 28),
                          borderRadius: BorderRadius.circular(15),
                          value: _selectedGender,
                          hint: const Text(
                            'Select gender',
                            style: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'Poppins',
                              fontSize: 14,
                            ),
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

                    // Height
                    _buildTextField(
                      label: 'Height (cm)',
                      controller: _heightController,
                      hint: 'Enter height in cm',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Weight
                    _buildTextField(
                      label: 'Weight (kg)',
                      controller: _weightController,
                      hint: 'Enter weight in kg',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 250), // space before bottom button
                  ],
                ),
              ),
            ),

            // Fixed button
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: _isSaving
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFC2868B)))
                  : ElevatedButton(
                onPressed: _saveInfant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFADADD),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Colors.black26, width: 1.2),
                  ),
                  elevation: 3,
                  shadowColor: Colors.black26,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom Text Field Widget
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
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Color(0xFFC2868B),
          ),
        ),
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
          validator: (value) =>
          validatorText ?? (value == null || value.isEmpty ? 'Please enter $label' : null),
        ),
      ],
    );
  }
}

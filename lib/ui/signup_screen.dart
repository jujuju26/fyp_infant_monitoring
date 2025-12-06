import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_success_screen.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  final String role; // "parent" or "staff"

  const SignUpScreen({super.key, required this.role});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreeToTerms = false;
  bool _isSaving = false; // show loader while saving

  // FIREBASE AUTH + FIRESTORE SAVE
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please agree to the Terms")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Check if the email is already in use
      final signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(_emailController.text.trim());
      if (signInMethods.isNotEmpty) {
        // If email is already in use
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email is already registered.')),
        );
        setState(() => _isSaving = false);
        return;
      }

      // Create Firebase Auth user
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Save additional data to Firestore
      final collectionName = widget.role == "parent" ? "parent" : "staff";
      final Map<String, dynamic> userData = {
        "uid": userCredential.user!.uid,
        "username": _usernameController.text.trim(),
        "email": _emailController.text.trim(),
        "role": widget.role,
        "created_at": DateTime.now(),
      };

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(userCredential.user!.uid)
          .set(userData);

      setState(() => _isSaving = false);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignUpSuccessScreen()),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering user: $e')),
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
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: _buildSignUpForm(),
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC2868B)),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFC2868B)),
          onPressed: () => Navigator.pop(context),
        ),
        Center(
          child: Column(
            children: [
              Image.asset('assets/images/logo2.png', height: 90),
              const SizedBox(height: 10),
              const Text(
                'LullaCare',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC2868B),
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                'Create an account',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2868B)),
              ),
              const SizedBox(height: 5),
              const Text(
                'Enter your information to sign up',
                style: TextStyle(fontSize: 14, color: Color(0xFFC2868B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField('Username', _usernameController, hintText: 'name'),
              _buildTextField('Email Address', _emailController,
                  hintText: 'example@gmail.com'),
              _buildTextField('Password', _passwordController,
                  obscure: true, hintText: '********'),
              _buildTextField('Confirm Password', _confirmPasswordController,
                  obscure: true, hintText: '********'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: _agreeToTerms,
                    onChanged: (v) => setState(() => _agreeToTerms = v!),
                    activeColor: const Color(0xFFC2868B),
                  ),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                              text: 'By continuing, you agree to our ',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFFC2868B))),
                          TextSpan(
                              text: 'Terms of Service ',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFC2868B),
                                  fontWeight: FontWeight.bold)),
                          TextSpan(
                              text: 'and ',
                              style:
                              TextStyle(fontSize: 12, color: Color(0xFFC2868B))),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC2868B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFADADD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.black26, width: 1.5),
                    ),
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already have an account? ",
                    style: TextStyle(color: Color(0xFFC2868B), fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => LoginScreen())),
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        color: Color(0xFFC2868B),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        fontSize: 13,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        )
      ],
    );
  }

  // TEXT FIELD BUILDER
  Widget _buildTextField(
      String label,
      TextEditingController controller, {
        bool obscure = false,
        String? hintText,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: Color(0xFFC2868B),
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              )),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderSide:
                const BorderSide(color: Color(0xFFFADADD), width: 1.2),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                const BorderSide(color: Color(0xFFC2868B), width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }

              if (label == "Email Address" &&
                  !RegExp(r"^[a-zA-Z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$")
                      .hasMatch(value)) {
                return "Enter a valid email";
              }

              if (label == "Password" && value.length < 6) {
                return "Password must be at least 6 characters";
              }

              if (label == "Confirm Password" &&
                  value != _passwordController.text) {
                return "Passwords do not match";
              }

              return null;
            },
          ),
        ],
      ),
    );
  }
}

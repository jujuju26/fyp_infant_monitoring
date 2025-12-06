import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _authReady = false;

  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _authReady = true;
      });
    });
  }

  Future<void> _loginAdmin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!mounted) return;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    // Basic validation
    if (email.isEmpty) {
      setState(() => _emailError = "Email cannot be empty");
      return;
    }
    if (!email.contains("@")) {
      setState(() => _emailError = "Enter a valid email");
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = "Password cannot be empty");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // SIGN IN
      UserCredential userCred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = userCred.user!.uid;

      // CHECK ADMIN COLLECTION
      final adminDoc = await FirebaseFirestore.instance
          .collection("admin")
          .doc(uid)
          .get();

      print("Admin doc: ${adminDoc.data()}");

      if (!mounted) return;

      // NOT ADMIN → DENY ACCESS
      if (!adminDoc.exists || adminDoc.data()?['role'] != "admin") {
        setState(() {
          _emailError = "Access denied. Please download LullaCare App.";
          _isLoading = false;
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      // SUCCESS — ADMIN VERIFIED
      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    }

    catch (e) {
      if (!mounted) return;
      setState(() {
        _emailError = "Invalid email or password";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          double boxWidth = constraints.maxWidth * 0.4;
          if (boxWidth < 300) boxWidth = constraints.maxWidth * 0.8;
          if (boxWidth > 500) boxWidth = 500;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Container(
                width: boxWidth,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo2.png', height: 120),
                    const SizedBox(height: 30),
                    const Text(
                      'Admin Login',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                        color: Color(0xFFC2868B),
                      ),
                    ),
                    const SizedBox(height: 25),

                    _buildInputLabel('Email Address'),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration("example@admin.com")
                          .copyWith(errorText: _emailError),
                    ),
                    const SizedBox(height: 18),

                    _buildInputLabel('Password'),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration("********").copyWith(
                        errorText: _passwordError,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            if (!mounted) return;
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        // DISABLE LOGIN UNTIL FIREBASE AUTH READY
                        onPressed: (!_authReady || _isLoading)
                            ? null
                            : _loginAdmin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFADADD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(
                                color: Colors.black26, width: 1.2),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2)
                            : const Text(
                          'Login',
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
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black38,
        fontFamily: 'Poppins',
        fontSize: 14,
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black26, width: 1.2),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Color(0xFFC2868B),
        ),
      ),
    );
  }
}

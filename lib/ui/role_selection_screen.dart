import 'package:flutter/material.dart';
import 'signup_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Color.fromRGBO(146, 88, 92, 1),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Logo
                        Center(
                          child: Image.asset(
                            'assets/images/logo2.png',
                            height: 100,
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Title
                        const Center(
                          child: Text(
                            "What's your role?",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC2868B),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Center(
                          child: Text(
                            "Select your role to continue signing up.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFC2868B),
                            ),
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Parent Role
                        _buildRoleOption(
                          context,
                          icon: Icons.family_restroom,
                          text: 'I am a parent',
                          role: 'parent', // <<< FIXED HERE
                        ),

                        const SizedBox(height: 25),

                        // Staff Role
                        _buildRoleOption(
                          context,
                          icon: Icons.medical_services_outlined,
                          text: 'I am a confinement centre staff',
                          role: 'staff', // <<< FIXED HERE
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleOption(
      BuildContext context, {
        required IconData icon,
        required String text,
        required String role, // <<< NEW PARAMETER
      }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      splashColor: const Color(0xFFC2868B).withOpacity(0.15),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SignUpScreen(role: role), // <<< FIXED HERE
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFADADD),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular icon background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF7EC8E3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Color(0xFFC2868B),
            ),
          ],
        ),
      ),
    );
  }
}

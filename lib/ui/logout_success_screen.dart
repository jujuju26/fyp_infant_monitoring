import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'; // for SystemNavigator.pop
import 'welcome_screen1.dart'; // because web cannot close app

class LogoutSuccessScreen extends StatelessWidget {
  const LogoutSuccessScreen({super.key});

  void _exitApp(BuildContext context) {
    if (kIsWeb) {
      // Web cannot close browser tab → redirect to welcome screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen1()),
            (route) => false,
      );
      return;
    }

    if (Platform.isAndroid) {
      SystemNavigator.pop(); // closes the app
    } else if (Platform.isIOS) {
      // iOS does not allow programmatic exit, so we pop the route stack
      Navigator.pop(context);
    } else {
      // Windows / Desktop
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable main area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 120),

                    // Icon
                    const Icon(
                      Icons.logout_rounded,
                      size: 230,
                      color: Color(0xFFFADADD),
                    ),
                    const SizedBox(height: 45),

                    // Title
                    const Text(
                      "Logout Successful!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC2868B),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Subtitle
                    const Text(
                      "You have successfully logged out.\nThank you for using LullaCare.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFC2868B),
                        fontSize: 15,
                        fontFamily: 'Poppins',
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Fixed bottom exit button
            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _exitApp(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFADADD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(
                        color: Colors.black26,
                        width: 1.5,
                      ),
                    ),
                    elevation: 3,
                    shadowColor: Colors.black26,
                  ),
                  child: const Text(
                    "Exit App",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

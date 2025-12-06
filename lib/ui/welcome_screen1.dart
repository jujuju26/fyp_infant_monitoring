import 'package:flutter/material.dart';
import '../widgets/welcome_page_indicator.dart';
import 'welcome_screen2.dart';

class WelcomeScreen1 extends StatelessWidget {
  const WelcomeScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // Scrollable if content exceeds screen height
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const Spacer(flex: 1),

                        // Image with soft border
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color.fromRGBO(250, 218, 221, 1),
                              width: 6,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/baby_pic.jpg',
                              height: 300,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Title
                        const Text(
                          'Smart Care, Gentle Support',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Color.fromRGBO(146, 88, 92, 1),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subtitle
                        const Text(
                          'LullaCare blends intelligent baby monitoring with a soothing design to keep you informed, connected, and reassured through every stage of growth.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                            fontSize: 13.5,
                            color: Colors.black54,
                            height: 1.5,
                          ),
                        ),

                        const Spacer(flex: 2),

                        const WelcomeProgressIndicator(currentPage: 1),

                        const SizedBox(height: 25),
                        // Next Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const WelcomeScreen2()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color.fromRGBO(250, 218, 221, 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: const BorderSide(
                                  color: Colors.black26,
                                  width: 1.5,
                                ),
                              ),
                              elevation: 3,
                              shadowColor: Colors.black26,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
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
}

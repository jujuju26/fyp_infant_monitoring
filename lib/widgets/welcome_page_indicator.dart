import 'package:flutter/material.dart';

class WelcomeProgressIndicator extends StatelessWidget {
  final int currentPage; // 1 or 2

  const WelcomeProgressIndicator({super.key, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(isActive: currentPage == 1),
        const SizedBox(width: 8),
        _dot(isActive: currentPage == 2),
      ],
    );
  }

  Widget _dot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 25 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: isActive
            ? const Color.fromRGBO(250, 218, 221, 1) // active pink
            : Colors.black12, // inactive grey
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

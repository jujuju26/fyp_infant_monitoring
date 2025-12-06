import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'ui/web/admin_dashboard_screen.dart';
import 'ui/web/web_login_screen.dart';
import 'ui/welcome_screen1.dart';
import 'ui/parent_home_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const LullaCareApp());
}

class LullaCareApp extends StatelessWidget {
  const LullaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LullaCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFC2868B),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFADADD),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Check if user is logged in
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFC2868B)),
            ),
          );
        }

        // USER LOGGED IN
        if (snapshot.hasData) {
          if (kIsWeb) {
            return const AdminDashboardScreen(); // Web home
          } else {
            return const ParentHomeScreen(); // App home
          }
        }

        // USER NOT LOGGED IN
        if (kIsWeb) {
          return const AdminLoginScreen(); // Web welcome
        } else {
          return const WelcomeScreen1(); // App welcome
        }
      },
    );
  }
}


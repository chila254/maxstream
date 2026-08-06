import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'maxstream_main_screen.dart';
import 'sign_in_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() async {
    try {
      debugPrint("SplashScreen: Waiting for splash delay + auth settle...");

      // Keep the logo visible for at least this long so every launch shows
      // the splash with its loading animation, whether signed in or not.
      final minimumDelay = Future<void>.delayed(const Duration(seconds: 3));

      // Wait for Firebase to restore a cached session before routing, so a
      // signed-in user is not briefly misrouted to the sign-in screen.
      final auth = FirebaseAuth.instance;
      final authSettled = auth.authStateChanges().first.timeout(
            const Duration(seconds: 8),
            onTimeout: () => auth.currentUser,
          );

      await Future.wait([minimumDelay, authSettled]);

      if (!mounted) return;

      final User? user = auth.currentUser;
      debugPrint("SplashScreen: User is ${user == null ? 'not signed in' : 'signed in'}");

      if (user == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MaxStreamMainScreen()),
        );
      }
    } catch (e) {
      debugPrint("SplashScreen Error: $e");
      if (!mounted) return;

      // In case of error, go to SignInScreen as fallback
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/maxstream_logo.png',
                width: 150,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.play_circle_fill,
                    size: 150,
                    color: Colors.red,
                  );
                },
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/index.dart';
import 'tv_login_screen.dart';
import 'tv_maxstream_main.dart';

class TvSplashScreen extends StatefulWidget {
  const TvSplashScreen({super.key});

  @override
  State<TvSplashScreen> createState() => _TvSplashScreenState();
}

class _TvSplashScreenState extends State<TvSplashScreen>
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

  void _navigateToNextScreen() async {
    try {
      debugPrint("TvSplashScreen: Waiting for splash delay + auth settle...");

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
      debugPrint("TvSplashScreen: User is ${user == null ? 'not signed in' : 'signed in'}");

      if (user == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const TvLoginScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TvMaxStreamMain()),
        );
      }
    } catch (e) {
      debugPrint("TvSplashScreen Error: $e");
      if (!mounted) return;

      // In case of error, go to the login screen as fallback
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const TvLoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = TvUtils.responsiveFontSize(200, context, maxSize: 300);

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
                width: logoSize,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.play_circle_fill,
                    size: logoSize,
                    color: Colors.red,
                  );
                },
              ),
              SizedBox(height: TvUtils.responsivePadding(24, context)),
              Text(
                'MaxStream TV',
                style: TvTypography.heroTitle,
              ),
              SizedBox(height: TvUtils.responsivePadding(32, context)),
              SizedBox(
                width: TvUtils.responsiveFontSize(60, context, maxSize: 80),
                height: TvUtils.responsiveFontSize(60, context, maxSize: 80),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  strokeWidth: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

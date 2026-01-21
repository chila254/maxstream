import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';
import 'screens/tv_splash_screen.dart';
import 'screens/tv_login_screen.dart';
import 'screens/tv_main_screen_netflix.dart';
import '../services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize notification service
    await NotificationService().initialize();

    runApp(const MaxStreamTV());
  } catch (e) {
    runApp(ErrorApp(error: e));
  }
}

class ErrorApp extends StatelessWidget {
  final Object error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Failed to initialize the app:\n$error',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class MaxStreamTV extends StatelessWidget {
  const MaxStreamTV({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaxStream TV',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const TvAuthGate(),
    );
  }
}

class TvAuthGate extends StatelessWidget {
  const TvAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TvSplashScreen();
        } else if (snapshot.hasData) {
          return const TvMainScreenNetflix(); // signed in
        } else {
          return const TvLoginScreen(); // not signed in
        }
      },
    );
  }
}

import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/splash_screen.dart';
import 'screens/maxstream_main_screen.dart';
import 'services/notification_service.dart';
import 'services/media_download_manager.dart';
import 'services/theme_service.dart';
import 'widgets/cloud_sync_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Remove name: 'MaxStreamApp' – only needed if initializing multiple apps
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (!kIsWeb) await NotificationService().initialize();
    if (!kIsWeb) await MediaDownloadManager.instance.initialize();
    await ThemeService.instance.loadTheme();

    // Check for updates after initialization
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _checkForUpdates();
    // });

    runApp(const MaxStreamApp());
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

class MaxStreamApp extends StatelessWidget {
  const MaxStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaxStream',
      theme: ThemeService.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const CloudSyncBootstrap(child: AuthGate()),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        } else if (snapshot.hasData) {
          return const MaxStreamMainScreen(); // signed in
        } else {
          return const SplashScreen(); // not signed in
        }
      },
    );
  }
}

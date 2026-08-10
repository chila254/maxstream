import 'dart:async';

import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/notification_router.dart';
import 'services/media_download_manager.dart';
import 'services/theme_service.dart';
import 'widgets/cloud_sync_bootstrap.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(() {
    runApp(const _StartupGate());
  }, (error, stack) {
    debugPrint('MaxStream uncaught zone error: $error\n$stack');
  });
}

/// Shows the MaxStream splash immediately and finishes network-backed service
/// initialization in the background, so a slow first launch (e.g. Firebase on a
/// cold start) can never leave the app frozen on the native splash drawable.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  Object? _fatal;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Remove name: 'MaxStreamApp' – only needed if initializing multiple apps
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (!kIsWeb) await NotificationService().initialize();
      if (!kIsWeb) await MediaDownloadManager.instance.initialize();
      await ThemeService.instance.loadTheme();
    } catch (e) {
      _fatal = e;
    }
    if (!mounted) return;
    setState(() => _ready = true);
    if (_fatal == null) {
      // Attach the navigator once the first frame is up so notification taps
      // (including cold-start taps) can be routed to the right screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationRouter.registerNavigator(appNavigatorKey);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fatal != null) return ErrorApp(error: _fatal!);
    if (!_ready) return const SplashScreen();
    return const MaxStreamApp();
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
      navigatorKey: appNavigatorKey,
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
    // The SplashScreen always plays first (logo + loading animation) and routes
    // to the right screen after the auth session settles, so the MaxStream logo
    // is visible on every launch whether or not the user is signed in.
    return const SplashScreen();
  }
}

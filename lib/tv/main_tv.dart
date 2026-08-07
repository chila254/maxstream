import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../services/notification_service.dart';
import '../widgets/cloud_sync_bootstrap.dart';
import 'screens/tv_login_screen.dart';
import 'screens/tv_maxstream_main.dart';
import 'screens/tv_splash_screen.dart';

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
      home: const CloudSyncBootstrap(child: TvAuthGate()),
    );
  }
}

class TvAuthGate extends StatefulWidget {
  const TvAuthGate({super.key});

  @override
  State<TvAuthGate> createState() => _TvAuthGateState();
}

class _TvAuthGateState extends State<TvAuthGate> {
  StreamSubscription<User?>? _authSub;
  User? _user;
  bool _authResolved = false;
  bool _minimumElapsed = false;

  @override
  void initState() {
    super.initState();

    final auth = FirebaseAuth.instance;

    // Wait for the first auth event so a cached session is restored before
    // routing; a signed-in user is never briefly misrouted to the login screen.
    // Every later auth change (sign-in or sign-out) swaps the screen too.
    _authSub = auth.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _user = user;
        _authResolved = true;
      });
    });

    // Keep the splash visible for at least this long so every launch shows
    // the logo with its loading animation, whether signed in or not.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _minimumElapsed = true);
    });

    // If the first auth event never arrives (rare), fall back to the current
    // user so the splash never blocks the app forever.
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted || _authResolved) return;
      setState(() {
        _user = auth.currentUser;
        _authResolved = true;
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The splash always plays first (logo + loading animation) while the
    // auth session settles, then the gate swaps to the right screen.
    if (!_authResolved || !_minimumElapsed) {
      return const TvSplashScreen();
    }
    return _user != null ? const TvMaxStreamMain() : const TvLoginScreen();
  }
}

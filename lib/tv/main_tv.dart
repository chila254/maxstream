import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../firebase_options.dart';
import '../services/notification_service.dart';
import '../widgets/cloud_sync_bootstrap.dart';
import '../widgets/crash_screen.dart';
import 'screens/tv_login_screen.dart';
import 'screens/tv_maxstream_main.dart';
import 'screens/tv_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalCrashHandlers();
  runZonedGuarded(() {
    // Analyze "opening" stability: render the splash immediately instead of
    // waiting for network-backed services before the first frame, and surface
    // any init failure inside the app rather than stalling on the native
    // splash drawable.
    runApp(const CrashReportGate(child: _TvStartupGate()));
  }, (error, stack) {
    recordCrash('UncaughtZone', error, stack);
  });
}

class _TvStartupGate extends StatefulWidget {
  const _TvStartupGate();

  @override
  State<_TvStartupGate> createState() => _TvStartupGateState();
}

class _TvStartupGateState extends State<_TvStartupGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize notification service
      await NotificationService().initialize();
    } catch (e, stack) {
      recordCrash('Bootstrap', e, stack);
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    // The splash is shown the moment the app opens, so a slow or unavailable
    // network during Firebase init can never leave the TV on a blank window.
    // It is a Scaffold, so it needs a MaterialApp ancestor before the main
    // TV MaterialApp is ready; building it bare at the runApp root crashes.
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const TvSplashScreen(),
      );
    }
    return const MaxStreamTV();
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
      // This app routes every back press through its own unified handler. If
      // the framework ever declines back handling the OS finishes the activity
      // directly, which is what made back exit the app. Always claim it.
      onNavigationNotification: (notification) {
        SystemNavigator.setFrameworkHandlesBack(true);
        return true;
      },
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

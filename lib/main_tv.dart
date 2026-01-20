import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/tv/tv_login_screen.dart';
import 'screens/tv/tv_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MaxStreamTV());
}

class MaxStreamTV extends StatelessWidget {
  const MaxStreamTV({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaxStream TV',
      theme: ThemeData.dark(),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const TvLoginScreen(),
        '/tv_home': (context) => const TvHomeScreen(),
      },
    );
  }
}

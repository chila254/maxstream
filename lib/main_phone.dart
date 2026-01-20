import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MaxStreamPhone());
}

class MaxStreamPhone extends StatelessWidget {
  const MaxStreamPhone({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaxStream',
      theme: ThemeData.dark(),
      home: const SplashScreen(),
    );
  }
}

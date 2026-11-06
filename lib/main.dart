import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase powers the AI label check. If it is not set
  // up yet (no `flutterfire configure`), the app still
  // works with on-device reading only.
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase not configured; AI label check disabled. $error');
  }

  runApp(const NutriPalApp());
}

class NutriPalApp extends StatelessWidget {
  const NutriPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutriPal',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
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
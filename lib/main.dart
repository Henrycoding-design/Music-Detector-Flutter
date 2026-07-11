import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MusicDetectorApp());
}

class MusicDetectorApp extends StatelessWidget {
  const MusicDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
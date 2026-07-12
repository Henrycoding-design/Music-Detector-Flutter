import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MusicDetectorApp());
}

class MusicDetectorApp extends StatefulWidget {
  const MusicDetectorApp({super.key});

  @override
  State<MusicDetectorApp> createState() => _MusicDetectorAppState();
}

class _MusicDetectorAppState extends State<MusicDetectorApp> {
  bool _isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Detector',
      debugShowCheckedModeBanner: false,
      // Deep elegant slate setups for rich look
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF6366F1), // Gorgeous Indigo Base
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF818CF8),
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: () => setState(() => _isDarkMode = !_isDarkMode),
      ),
    );
  }
}
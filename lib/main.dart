import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('is_dark_mode') ?? true;
  runApp(MusicDetectorApp(initialDarkMode: isDarkMode));
}

class MusicDetectorApp extends StatefulWidget {
  final bool? initialDarkMode;
  const MusicDetectorApp({super.key, this.initialDarkMode});

  @override
  State<MusicDetectorApp> createState() => _MusicDetectorAppState();
}

class _MusicDetectorAppState extends State<MusicDetectorApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode ?? true;
    if (widget.initialDarkMode == null) {
      _loadThemeFromPrefs();
    }
  }

  void _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode');
    if (isDark != null && isDark != _isDarkMode) {
      setState(() {
        _isDarkMode = isDark;
      });
    }
  }

  void _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Finder',
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
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
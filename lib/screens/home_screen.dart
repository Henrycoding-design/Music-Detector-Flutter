import 'package:flutter/material.dart';
import 'recognition_page.dart';
import 'history_page.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showHistory = false;
  bool _isLoading = false;
  Key _historyKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Music Detector",
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_showHistory ? Icons.home_rounded : Icons.history_rounded),
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _showHistory = !_showHistory;
                      if (_showHistory) {
                        _historyKey = UniqueKey();
                      }
                    });
                  },
            tooltip: _isLoading
                ? "Processing..."
                : (_showHistory ? "Back to Home" : "Search History"),
          ),
          SizedBox(
            width: 8,
            height: 24,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant,
              ),
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
            tooltip: "Toggle Theme",
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: IndexedStack(
        index: _showHistory ? 1 : 0,
        children: [
          RecognitionPage(
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
            onLoadingChanged: (loading) {
              setState(() {
                _isLoading = loading;
              });
            },
          ),
          HistoryPage(
            key: _historyKey,
          ),
        ],
      ),
    );
  }
}
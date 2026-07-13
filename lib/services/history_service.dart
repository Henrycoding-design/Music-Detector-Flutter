import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

class HistoryService {
  static const String _historyKey = "search_history";
  static const int _maxHistory = 20;

  /// Loads the history, ordered from newest to oldest.
  /// Returns an empty list if nothing exists or if any error occurs (never throws).
  /// If JSON decoding fails, it returns an empty history.
  static Future<List<HistoryItem>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? historyJsonList = prefs.getStringList(_historyKey);
      if (historyJsonList == null) {
        return [];
      }
      final List<HistoryItem> items = [];
      for (final jsonStr in historyJsonList) {
        try {
          final decoded = json.decode(jsonStr);
          if (decoded is Map<String, dynamic>) {
            items.add(HistoryItem.fromJson(decoded));
          } else {
            return []; // Invalid structure
          }
        } catch (e) {
          // Invalid JSON should return an empty history
          return [];
        }
      }
      return items;
    } catch (e) {
      return [];
    }
  }

  /// Saves a new history item.
  /// Inserts it at the beginning of the list, trims to max 20, and writes back.
  static Future<void> save(HistoryItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await load();
      
      // Insert new item at index 0 (newest first)
      history.insert(0, item);
      
      // Trim to keep only the 20 most recent
      if (history.length > _maxHistory) {
        history.removeRange(_maxHistory, history.length);
      }
      
      final List<String> historyJsonList = history
          .map((item) => json.encode(item.toJson()))
          .toList();
          
      await prefs.setStringList(_historyKey, historyJsonList);
    } catch (e) {
      // Never throw
    }
  }

  /// Deletes one entry at the specified index.
  static Future<void> remove(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await load();
      if (index >= 0 && index < history.length) {
        history.removeAt(index);
        final List<String> historyJsonList = history
            .map((item) => json.encode(item.toJson()))
            .toList();
        await prefs.setStringList(_historyKey, historyJsonList);
      }
    } catch (e) {
      // Never throw
    }
  }

  /// Deletes all history.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      // Never throw
    }
  }

  /// Returns the number of stored searches.
  static Future<int> count() async {
    try {
      final history = await load();
      return history.length;
    } catch (e) {
      return 0;
    }
  }
}

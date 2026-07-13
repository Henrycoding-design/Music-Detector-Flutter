import 'parse_result.dart';

class HistoryItem {
  final String input;
  final bool isUrl;
  final DateTime timestamp;
  final List<SongGuess> results;

  HistoryItem({
    required this.input,
    required this.isUrl,
    required this.timestamp,
    required this.results,
  });

  Map<String, dynamic> toJson() {
    return {
      'input': input,
      'isUrl': isUrl,
      'timestamp': timestamp.toIso8601String(),
      'results': results.map((guess) => guess.toJson()).toList(),
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final resultsJson = json['results'] as List<dynamic>? ?? [];
    return HistoryItem(
      input: json['input'] as String? ?? '',
      isUrl: json['isUrl'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      results: resultsJson
          .map((item) => SongGuess.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

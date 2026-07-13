import '../models/parse_result.dart';
export '../models/parse_result.dart';

class ResultParser {
  static List<SongGuess> parse(Map<String, dynamic> json) {
    final success = json['success'] == true;

    if (!success) {
      throw Exception(json['error'] ?? 'Recognition failed.');
    }

    final results = json['result'] as List<dynamic>? ?? [];

    if (results.isEmpty) {
      throw Exception('No matches found for uploaded audio.');
    }

    final guesses = results.map((item) {
      final recording = item['recording'] as Map<String, dynamic>? ?? {};

      return SongGuess(
        confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
        title: recording['title'] ?? 'Unknown',
        artist: recording['artist'] ?? 'Unknown',
        album: item['album'] ?? 'Unknown',
        releaseDate: item['releaseDate'],
        isrc: item['isrc'],
        genres: List<String>.from(item['genres'] ?? []),
        cover: item['cover'],
        shazamUrl: item['shazamUrl'],
      );
    }).toList();

    guesses.sort((a,b) => b.confidence.compareTo(a.confidence));

    return guesses;
  }
}
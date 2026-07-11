class SongGuess {
  final double confidence;
  final String title;
  final String artist;
  final String album;
  final String? releaseDate;
  final String? isrc;
  final List<String> genres;
  final String? cover;
  final String? shazamUrl;

  SongGuess({
    required this.confidence,
    required this.title,
    required this.artist,
    required this.album,
    this.releaseDate,
    this.isrc,
    required this.genres,
    this.cover,
    this.shazamUrl,
  });
}

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

    return results.map((item) {
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
  }
}
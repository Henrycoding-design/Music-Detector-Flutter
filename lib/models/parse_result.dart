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

  Map<String, dynamic> toJson() {
    return {
      'confidence': confidence,
      'title': title,
      'artist': artist,
      'album': album,
      'releaseDate': releaseDate,
      'isrc': isrc,
      'genres': genres,
      'cover': cover,
      'shazamUrl': shazamUrl,
    };
  }

  factory SongGuess.fromJson(Map<String, dynamic> json) {
    return SongGuess(
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? 'Unknown',
      album: json['album'] as String? ?? 'Unknown',
      releaseDate: json['releaseDate'] as String?,
      isrc: json['isrc'] as String?,
      genres: List<String>.from(json['genres'] ?? []),
      cover: json['cover'] as String?,
      shazamUrl: json['shazamUrl'] as String?,
    );
  }
}

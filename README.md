# Music Finder

A cross-platform Flutter client for the **Music Detector Backend**, providing a clean and responsive interface for identifying songs from either uploaded audio files or public media URLs.

## Features

- 🎵 Upload audio files from your device
- 🔗 Recognize songs directly from public media links (YouTube, TikTok, Instagram, SoundCloud, etc.)
- 🌐 Flutter Web support (currently tested on Google Chrome)
- 📡 Communicates with the Music Detector Backend via HTTP
- 🎨 Responsive Material Design interface with audio file and URL recognition tabs
- 📝 Displays recognition results including:
  - Song title
  - Artist
  - Album
  - Release date
  - Album artwork
  - Genres
  - Shazam link
  - Confidence score
- ⚠️ Graceful backend error handling

---

## Backend API

This client communicates with the Music Detector Backend through two endpoints.

### Audio File Recognition

```http
POST /recognize
Content-Type: multipart/form-data

file=<audio file>
```

### URL Recognition

```http
POST /urlRecognize
Content-Type: application/json

{
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
}
```

Both endpoints return the same recognition response format.

Example response:

```json
{
  "success": true,
  "result": [
    {
      "confidence": 0.9949,
      "recording": {
        "title": "Faded (acoustic version)",
        "artist": "Sara Farell"
      },
      "album": "Faded (acoustic version)",
      "releaseDate": "2016-01-06",
      "isrc": "SEWDL6141687"
    }
  ]
}
```

---

## Tech Stack

- Flutter
- Dart
- Material Design 3
- HTTP
- file_picker
- url_launcher

---

## Project Structure

```text
lib/
├── main.dart
├── screens/
|   ├── home_screen.dart
│   └── loading_animation.dart
└── services/
    ├── api_service.dart
    └── parse_result.dart
```

---

## Configuration

The backend URL is injected at compile time using Flutter's `--dart-define`.

```dart
const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);
```

### Local Development

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:3000
```

or configure the value inside `.vscode/launch.json`.

### Production

For deployment (for example on Vercel), set the environment variable:

```text
API_BASE_URL=https://your-backend.example.com
```

and build with:

```bash
flutter build web \
  --release \
  --dart-define=API_BASE_URL=$API_BASE_URL
```

---

## Getting Started

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run -d chrome
```

---

## Roadmap

- [x] Basic Material UI
- [x] Audio file picker
- [x] Multipart file upload
- [x] URL recognition
- [x] Backend communication
- [x] Recognition result parsing
- [x] Error handling
- [x] Recognition result cards
- [x] Album artwork display
- [x] Genre display
- [x] Shazam links
- [x] Responsive layouts
- [ ] UI polishing
- [ ] Recognition history
- [ ] Android support
- [ ] Windows support
- [ ] iOS support
- [ ] Desktop packaging

---

## License

This project is licensed under the MIT License.

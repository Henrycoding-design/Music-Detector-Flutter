# Music Detector Client

A cross-platform Flutter client for the **Music Detector Backend**, providing a simple interface for uploading audio files and viewing music recognition results.

## Features

* 🎵 Upload audio files from your device
* 🌐 Works on Flutter Web (currently tested on Google Chrome)
* 📡 Connects to the Music Detector Backend via HTTP
* 📝 Displays multiple recognition guesses with:

  * Song title
  * Artist
  * Album
  * Release date
  * ISRC
  * Confidence score
* ⚠️ Displays backend error messages when recognition fails

## Backend

This client communicates with the Music Detector Backend:

```
POST /recognize
```

using `multipart/form-data`.

Example request:

```http
POST /recognize
Content-Type: multipart/form-data

file=<audio file>
```

Expected response:

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

## Tech Stack

* Flutter
* Dart
* HTTP
* file_picker

## Project Structure

```
lib/
├── main.dart
├── screens/
│   └── home_screen.dart
└── services/
    ├── api_service.dart
    └── parse_result.dart
```

## Getting Started

Install dependencies:

```bash
flutter pub get
```

Run on Chrome:

```bash
flutter run -d chrome
```

## Current Status

Current implementation includes:

* Basic Material UI
* Audio file picker
* Multipart file upload
* Backend communication
* Recognition result parsing
* Error handling
* Recognition result cards

## Planned Features

* Album artwork display
* Shazam links
* Genre display
* URL recognition
* Recognition history
* Responsive layouts
* Android support
* Windows support
* iOS support
* Desktop packaging

## License

This project is licensed under the MIT License.

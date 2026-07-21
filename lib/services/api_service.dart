import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static Future<Map<String, dynamic>> recognize(
      PlatformFile file) async {
    if (file.bytes == null) {
      throw Exception(
          'File bytes are unavailable. Make sure withData: true is used.');
    }

    final uri = Uri.parse('$_baseUrl/recognize');

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
      );
    }
  }

  static Future<Map<String, dynamic>> urlRecognize(
    String url,
  ) async {
    final uri = Uri.parse('$_baseUrl/urlRecognize');

    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'url': url,
      }),
    );

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
      );
    }
  }

  static Future<Map<String, dynamic>> recordingRecognize(
    String filePath, {
    Uint8List? bytes,
    String? filename,
  }) async {
    final uri = Uri.parse('$_baseUrl/recordingRecognize');

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    if (bytes != null && bytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename ?? 'recording.m4a',
        ),
      );
    } else if (kIsWeb) {
      final response = await http.get(Uri.parse(filePath));
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          response.bodyBytes,
          filename: filename ?? 'recording.m4a',
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          // If filename isn't provided, derive it from the file path.
          // r'[/\\]' is a raw RegExp that matches either '/' (Linux/macOS/Android/iOS)
          // or '\' (Windows). split(...).last returns the last path segment (the filename).
          filename: filename ?? filePath.split(RegExp(r'[/\\]')).last,
        ),
      );
    }

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception(
        'The server returned an invalid response (HTTP ${response.statusCode}).',
      );
    }
  }
}
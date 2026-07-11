import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl =
      'https://music-detector-backend.onrender.com';

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
}
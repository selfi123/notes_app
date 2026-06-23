import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class R2Service {
  // Points to your secure PythonAnywhere backend
  static String get _apiUrl => dotenv.env['BACKEND_API_URL'] ?? 'https://yourusername.pythonanywhere.com';
  
  // The secret key must match the Python backend API_SECRET_KEY
  static String get _apiKey => dotenv.env['API_SECRET_KEY'] ?? 'voicecard-secure-api-key-2026';

  static Map<String, String> get _headers => {
        'x-api-key': _apiKey,
        'Content-Type': 'application/json',
      };

  /// Upload an audio file securely via a backend Pre-signed URL.
  static Future<String> uploadAudio({
    required String localPath,
    required String objectKey,
  }) async {
    // 1. Get Pre-signed PUT URL from our secure backend
    final response = await http.get(
      Uri.parse('\$_apiUrl/generate-upload-url?key=\$objectKey'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get upload URL: \${response.body}');
    }

    final data = jsonDecode(response.body);
    final String presignedUrl = data['url'];

    // 2. Upload file directly to Cloudflare R2
    final file = File(localPath);
    final fileBytes = await file.readAsBytes();

    final uploadResponse = await http.put(
      Uri.parse(presignedUrl),
      body: fileBytes,
      headers: {
        'Content-Type': 'audio/mp4', // Ensure standard MIME type for M4A
      },
    );

    if (uploadResponse.statusCode != 200) {
      throw Exception('Failed to upload directly to R2: \${uploadResponse.statusCode}');
    }

    return objectKey;
  }

  /// Download an audio file securely via a backend Pre-signed URL.
  static Future<String> downloadAudio({
    required String objectKey,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final fileName = objectKey.split('/').last;
    final localPath = '\${cacheDir.path}/\$fileName';

    final localFile = File(localPath);
    if (await localFile.exists()) {
      return localPath; // Already cached
    }

    // 1. Get Pre-signed GET URL from our secure backend
    final response = await http.get(
      Uri.parse('\$_apiUrl/generate-download-url?key=\$objectKey'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get download URL: \${response.body}');
    }

    final data = jsonDecode(response.body);
    final String presignedUrl = data['url'];

    // 2. Download file directly from Cloudflare R2
    final downloadResponse = await http.get(Uri.parse(presignedUrl));
    
    if (downloadResponse.statusCode != 200) {
      throw Exception('Failed to download from R2: \${downloadResponse.statusCode}');
    }

    await localFile.writeAsBytes(downloadResponse.bodyBytes);
    return localPath;
  }

  /// Delete an audio file securely via backend command.
  static Future<void> deleteAudio(String objectKey) async {
    final response = await http.post(
      Uri.parse('\$_apiUrl/delete-audio'),
      headers: _headers,
      body: jsonEncode({'key': objectKey}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete audio: \${response.body}');
    }
  }

  /// Generate a unique object key for a note.
  static String buildKey({
    required String contactId,
    required String noteId,
  }) {
    return 'audio/\$contactId/\$noteId.m4a';
  }
}

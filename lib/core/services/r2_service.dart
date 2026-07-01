import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'backend_api.dart';

class R2Service {
  /// Upload an audio file securely via a backend Pre-signed URL.
  static Future<String> uploadAudio({
    required String localPath,
    required String objectKey,
  }) async {
    final response = await http.get(
      Uri.parse('${BackendApi.baseUrl}/generate-upload-url?key=$objectKey'),
      headers: BackendApi.headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get upload URL: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final String presignedUrl = data['url'];

    final file = File(localPath);
    final fileBytes = await file.readAsBytes();

    final uploadResponse = await http.put(
      Uri.parse(presignedUrl),
      body: fileBytes,
      headers: const {
        'Content-Type': 'audio/mp4',
      },
    );

    if (uploadResponse.statusCode != 200) {
      throw Exception(
        'Failed to upload directly to R2: ${uploadResponse.statusCode}',
      );
    }

    return objectKey;
  }

  /// Download an audio file securely via a backend Pre-signed URL.
  static Future<String> downloadAudio({
    required String objectKey,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final fileName = objectKey.split('/').last;
    final localPath = '${cacheDir.path}/$fileName';

    final localFile = File(localPath);
    if (await localFile.exists()) {
      return localPath;
    }

    final response = await http.get(
      Uri.parse('${BackendApi.baseUrl}/generate-download-url?key=$objectKey'),
      headers: BackendApi.headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get download URL: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final String presignedUrl = data['url'];

    final downloadResponse = await http.get(Uri.parse(presignedUrl));

    if (downloadResponse.statusCode != 200) {
      throw Exception(
        'Failed to download from R2: ${downloadResponse.statusCode}',
      );
    }

    await localFile.writeAsBytes(downloadResponse.bodyBytes);
    return localPath;
  }

  /// Delete an audio file securely via backend command.
  static Future<void> deleteAudio(String objectKey) async {
    final response = await http.post(
      Uri.parse('${BackendApi.baseUrl}/delete-audio'),
      headers: BackendApi.headers,
      body: jsonEncode({'key': objectKey}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete audio: ${response.body}');
    }
  }

  /// Generate a unique object key for a note.
  static String buildKey({
    required String contactId,
    required String noteId,
  }) {
    return 'audio/$contactId/$noteId.m4a';
  }
}

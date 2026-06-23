import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:minio/minio.dart';
import 'package:path_provider/path_provider.dart';

class R2Service {
  static Minio? _client;

  static Minio get client {
    _client ??= Minio(
      endPoint:
          '${dotenv.env['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com',
      accessKey: dotenv.env['R2_ACCESS_KEY_ID'] ?? '',
      secretKey: dotenv.env['R2_SECRET_ACCESS_KEY'] ?? '',
      useSSL: true,
      port: 443,
    );
    return _client!;
  }

  static String get _bucket => dotenv.env['R2_BUCKET_NAME'] ?? 'notes';

  /// Upload an audio file to R2. Returns the object key on success.
  static Future<String> uploadAudio({
    required String localPath,
    required String objectKey,
  }) async {
    final file = File(localPath);
    // minio v3 requires Stream<Uint8List>
    final stream = file.openRead().cast<Uint8List>();

    await client.putObject(
      _bucket,
      objectKey,
      stream,
    );

    return objectKey;
  }

  /// Download an audio file from R2 to local cache. Returns local path.
  static Future<String> downloadAudio({
    required String objectKey,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final fileName = objectKey.split('/').last;
    final localPath = '${cacheDir.path}/$fileName';

    final localFile = File(localPath);
    if (await localFile.exists()) {
      return localPath; // Already cached
    }

    final stream = await client.getObject(_bucket, objectKey);
    final sink = localFile.openWrite();
    await stream.pipe(sink);
    await sink.close();

    return localPath;
  }

  /// Delete an audio file from R2.
  static Future<void> deleteAudio(String objectKey) async {
    await client.removeObject(_bucket, objectKey);
  }

  /// Generate an R2 object key for a note.
  static String buildKey({
    required String contactId,
    required String noteId,
  }) {
    return 'audio/$contactId/$noteId.m4a';
  }
}
